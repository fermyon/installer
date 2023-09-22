#!/usr/bin/env bash
set -euo pipefail

export NOMAD_VAR_admin_username="${HIPPO_ADMIN_USERNAME:=admin}"
export NOMAD_VAR_admin_password="${HIPPO_ADMIN_PASSWORD:=password}"

# Early exit for unsupported systems
case "${OSTYPE}" in
  linux-gnu* | darwin*)
    ;; # Linux, MacOS, and WSL2 can proceed
  msys | cygwin)
    echo "The ${OSTYPE} environment is not yet supported for the Fermyon platform."
    echo "But it will work within the Windows Subsystem for Linux."
    echo "See https://docs.microsoft.com/en-us/windows/wsl/install for details."
    exit 1
    ;;
  *)
    echo "The ${OSTYPE} environment is not yet supported for the Fermyon platform."
    exit 1
    ;;
esac

require() {
  if ! hash "$1" &>/dev/null; then
    echo "'$1' not found in PATH"
    exit 1
  fi
}

require consul
require nomad
require spin

# NOTE(bacongobbler): nomad MUST run as root for the exec driver to work on Linux.
# https://github.com/deislabs/hippo/blob/de73ae52d606c0a2351f90069e96acea831281bc/src/Infrastructure/Jobs/NomadJob.cs#L28
# https://www.nomadproject.io/docs/drivers/exec#client-requirements
case "$OSTYPE" in
  linux*)
    require sudo
    SUDO="sudo --preserve-env=PATH"
    ;;
  *)
    SUDO=
    ;;
esac

cleanup() {
  echo
  echo "Shutting down services"
  kill $(jobs -p)
  wait
}
trap cleanup EXIT

# change to the directory of this script
cd "$(dirname "${BASH_SOURCE[0]}")"

${SUDO} rm -rf ./data
mkdir -p log

echo "Starting consul..."
consul agent -dev \
  -config-file ./etc/consul.hcl \
  -bootstrap-expect 1 \
  &>log/consul.log &

echo "Waiting for consul..."
while ! consul members &>/dev/null; do
  sleep 2
done

echo "Starting nomad..."
${SUDO} nomad agent -dev \
  -config ./etc/nomad.hcl \
  -data-dir "${PWD}/data/nomad" \
  -consul-address "127.0.0.1:8500" \
  &>log/nomad.log &

echo "Waiting for nomad..."
while ! nomad server members 2>/dev/null | grep -q alive; do
  sleep 2
done

echo "Starting traefik job..."
nomad run job/traefik.nomad

echo "Starting bindle job..."

case "$(uname -m)" in
  amd64 | x86_64)
    export NOMAD_VAR_arch=amd64
    ;;
  aarch64 | arm64)
    export NOMAD_VAR_arch=aarch64
    ;;
  *)
    echo "$(uname -m) architecture not supported."
    ;;
esac

case "${OSTYPE}" in
  linux*)
    export NOMAD_VAR_os=linux
    nomad run job/bindle.nomad
    ;;
  darwin*)
    export NOMAD_VAR_os=macos
    nomad run job/bindle.nomad
    ;;
  *)
    echo "Bindle is only started on MacOS and Linux"
    ;;
esac

echo "Starting hippo job..."

# Hippo uses different terms to describe architecture than bindle does, so we
# need to re-export our `arch` variable
case "$(uname -m)" in
  amd64 | x86_64)
    export NOMAD_VAR_arch=x64
    ;;
  aarch64 | arm64)
    export NOMAD_VAR_arch=arm64
    ;;
  *)
    echo "$(uname -m) architecture not supported."
    ;;
esac

case "${OSTYPE}" in
  linux*)
    # Our os declaration will have been set above for bindle and doesn't
    # change for hippo
    nomad run job/hippo.nomad
    ;;
  darwin*)
    # Hippo and bindle use different terms for mac support though, so we 
    # re-export that value here.
    export NOMAD_VAR_os=osx NOMAD_VAR_arch=x64
    nomad run job/hippo.nomad
    ;;
  *)
    echo "Hippo is only started on MacOS and Linux"
    ;;
esac

# Required until hippo's healthz endpoint returns 404 when not ready.
# Ref: https://github.com/fermyon/installer/pull/50
echo 'Waiting for application to be accessible'
HIPPO_URL="http://hippo.local.fermyon.link"
while ! curl -s "${HIPPO_URL}/healthz"| grep -q "Healthy";  do
  sleep 1
done

echo
echo "Dashboards"
echo "----------"
echo "Consul:  http://localhost:8500"
echo "Nomad:   http://localhost:4646"
echo "Traefik: http://localhost:8081"
echo "Hippo:   http://hippo.local.fermyon.link"
echo
echo "Logs are stored in ./log"
echo
echo "Export these into your shell"
echo
echo "    export CONSUL_HTTP_ADDR=http://localhost:8500"
echo "    export NOMAD_ADDR=http://localhost:4646"
echo "    export BINDLE_URL=http://bindle.local.fermyon.link/v1"
echo "    export HIPPO_URL=http://hippo.local.fermyon.link"
echo
echo "Ctrl+C to exit."
echo

wait

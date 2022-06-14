#!/usr/bin/env bash
set -euo pipefail

require() {
  if ! hash "$1" &>/dev/null; then
    echo "'$1' not found in PATH"
    exit 1
  fi
}

require consul
require nomad

cleanup() {
  echo
  echo "Shutting down services"
  kill $(jobs -p)
  wait
}
trap cleanup EXIT

echo "Waiting for consul..."
while ! consul members &>/dev/null; do
  sleep 2
done

# NOTE(bacongobbler): nomad MUST run as root for the exec driver to work on Linux.
# https://github.com/deislabs/hippo/blob/de73ae52d606c0a2351f90069e96acea831281bc/src/Infrastructure/Jobs/NomadJob.cs#L28
# https://www.nomadproject.io/docs/drivers/exec#client-requirements
case "$OSTYPE" in
  linux*) SUDO="sudo --preserve-env=PATH" ;;
  *) SUDO= ;;
esac

# change to the directory of this script
cd "$(dirname "${BASH_SOURCE[0]}")"

${SUDO} rm -rf ./data
mkdir -p log

echo "Starting consul..."
consul agent -dev \
  -config-file ./etc/consul.hcl \
  -bootstrap-expect 1 \
  &>log/consul.log &

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
    arch=amd64
    ;;
  aarch64 | arm64)
    arch=aarch64
    ;;
  *)
    echo "$(uname -m) architecture not supported."
    ;;
esac

case "${OSTYPE}" in
  darwin*)
    nomad run -var="os=macos" -var="arch=${arch}" job/bindle.nomad
    ;;
  linux*)
    nomad run -var="os=linux" -var="arch=${arch}" job/bindle.nomad
    ;;
  *)
    echo "Bindle is only started on MacOS and Linux"
    ;;
esac

echo "Starting hippo job..."

case "${OSTYPE}" in
  darwin*)
    nomad run -var="os=osx" job/hippo.nomad
    ;;
  linux*)
    nomad run -var="os=linux" -var="driver=exec" job/hippo.nomad
    ;;
  *)
    echo "Hippo is only started on MacOS and Linux"
    ;;
esac

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

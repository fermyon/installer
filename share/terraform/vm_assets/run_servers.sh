#!/usr/bin/env bash
set -euo pipefail

# Derived from https://github.com/fermyon/nomad-local-demo

export DNS_ZONE="${DNS_ZONE:-local.fermyon.link}"
export ENABLE_LETSENCRYPT="${ENABLE_LETSENCRYPT:-false}"

if $ENABLE_LETSENCRYPT; then
  export PLATFORM_PROTOCOL="https"
else
  export PLATFORM_PROTOCOL="http"
fi

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=devroot

require() {
  if ! hash "$1" &>/dev/null; then
    echo "'$1' not found in PATH"
    exit 1
  fi
}

require nomad
require consul
require vault
require bindle-server

cleanup() {
  echo
  echo "Shutting down services"
  kill $(jobs -p)
  wait
}

trap cleanup EXIT

rm -rf ./data
mkdir -p log data/vault

# https://www.nomadproject.io/docs/faq#q-how-to-connect-to-my-host-network-when-using-docker-desktop-windows-and-macos

IP_ADDRESS=$(hostname -I | xargs | awk '{print $1}')

echo "Starting consul..."
consul agent -dev \
  -config-file ./etc/consul.hcl \
  -bootstrap-expect 1 \
  -client '0.0.0.0' \
  -bind "${IP_ADDRESS}" \
  &>log/consul.log &

echo "Waiting for consul..."
while ! consul members &>/dev/null; do
  sleep 2
done

echo "Starting vault..."
vault server -dev \
  -dev-root-token-id "$VAULT_TOKEN" \
  -config ./etc/vault.hcl \
  &>log/vault.log &

echo "Waiting for vault..."
while ! grep -q 'Unseal Key' <log/vault.log; do
  sleep 2
done

echo "Storing unseal token in ./data/vault/unseal"
if [ ! -f data/vault/unseal ]; then
  awk '/^Root Token:/ { print $NF }' <log/vault.log >data/vault/token
  awk '/^Unseal Key:/ { print $NF }' <log/vault.log >data/vault/unseal
fi

echo "Starting nomad..."
nomad agent -dev \
  -config ./etc/nomad.hcl \
  -network-interface $(ip -o -4 route show to default | awk '{print $5}') \
  -data-dir "${PWD}/data/nomad" \
  -consul-address "${IP_ADDRESS}:8500" \
  -vault-address http://127.0.0.1:8200 \
  -vault-token "${VAULT_TOKEN}" \
   &>log/nomad.log &

echo "Waiting for nomad..."
while ! nomad server members 2>/dev/null | grep -q alive; do
  sleep 2
done

echo "Starting traefik job..."
nomad run job/traefik.nomad

echo "Starting bindle job..."
nomad run \
  -var domain="bindle.${DNS_ZONE}" \
  -var enable_letsencrypt="${ENABLE_LETSENCRYPT}" \
  job/bindle.nomad

echo "Starting hippo job..."
nomad run \
  -var hippo_folder="${HIPPO_FOLDER}" \
  -var domain="hippo.${DNS_ZONE}" \
  -var registration_mode="${HIPPO_REGISTRATION_MODE}" \
  -var admin_username="${HIPPO_ADMIN_USERNAME}" \
  -var admin_password="${HIPPO_ADMIN_PASSWORD}" \
  -var bindle_url="${PLATFORM_PROTOCOL}://bindle.${DNS_ZONE}/v1" \
  -var enable_letsencrypt="${ENABLE_LETSENCRYPT}" \
  job/hippo.nomad

echo
echo "Dashboards"
echo "----------"
echo "Consul:  http://localhost:8500"
echo "Nomad:   http://localhost:4646"
echo "Vault:   http://localhost:8200"
echo "Traefik: http://localhost:8081"
echo "Hippo:   ${PLATFORM_PROTOCOL}://hippo.${DNS_ZONE}"
echo
echo "Logs are stored in ./log"
echo
echo "Export these into your shell"
echo
echo "    export CONSUL_HTTP_ADDR=http://${IP_ADDRESS}:8500"
echo "    export NOMAD_ADDR=http://127.0.0.1:4646"
echo "    export VAULT_ADDR=${VAULT_ADDR}"
echo "    export VAULT_TOKEN=$(<data/vault/token)"
echo "    export VAULT_UNSEAL=$(<data/vault/unseal)"
echo "    export BINDLE_URL=${PLATFORM_PROTOCOL}://bindle.${DNS_ZONE}/v1"
echo "    export HIPPO_URL=${PLATFORM_PROTOCOL}://hippo.${DNS_ZONE}"
echo
echo "Ctrl+C to exit."
echo

wait

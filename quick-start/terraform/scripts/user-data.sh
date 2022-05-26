#!/usr/bin/env bash
set -euo pipefail

# Output can be seen at /var/log/cloud-init-output.log

# Note: this is used as a template in Terraform, where vars are injected to
# produce the final version. As such, all vars *not* intended to be resolved
# at the Terraform level should just be '$var'.  

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

function validate-checksum() {
  local readonly file="$1"
  local readonly want="$2"
  local readonly got="$(sha256sum "$file" | cut -d' ' -f1)"

  [ "$got" == "$want" ] || \
    (echo "ERROR: $file checksums don't match; want $want, got $got" && exit 1)
}

# -----------------------------------------------------------------------------
# Install deps
# -----------------------------------------------------------------------------

cd /tmp

## Install misc utilities
sudo apt-get update && sudo apt-get install -y \
  curl \
  unzip

## TODO: Install Docker?

## Install Hashistack & co deps

echo "Install Nomad"
curl -sO https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip
validate-checksum "nomad_${nomad_version}_linux_amd64.zip" "${nomad_checksum}"
sudo unzip nomad_${nomad_version}_linux_amd64.zip -d /usr/local/bin
sudo chmod +x /usr/local/bin/nomad
nomad --version

echo "Install Consul"
curl -sO https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
validate-checksum "consul_${consul_version}_linux_amd64.zip" "${consul_checksum}"
sudo unzip consul_${consul_version}_linux_amd64.zip -d /usr/local/bin
sudo chmod +x /usr/local/bin/consul
consul --version

echo "Install Vault"
curl -sO https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip
validate-checksum "vault_${vault_version}_linux_amd64.zip" "${vault_checksum}"
sudo unzip vault_${vault_version}_linux_amd64.zip -d /usr/local/bin
sudo chmod +x /usr/local/bin/vault
vault --version

echo "Install Traefik"
curl -sLO https://github.com/traefik/traefik/releases/download/${traefik_version}/traefik_${traefik_version}_linux_amd64.tar.gz
validate-checksum "traefik_${traefik_version}_linux_amd64.tar.gz" "${traefik_checksum}"
sudo tar zxvf traefik_${traefik_version}_linux_amd64.tar.gz -C /usr/local/bin
sudo chmod +x /usr/local/bin/traefik
traefik version

## Install Fermyon Platform deps

echo "Install Bindle"
curl -sO https://bindle.blob.core.windows.net/releases/bindle-${bindle_version}-linux-amd64.tar.gz
validate-checksum "bindle-${bindle_version}-linux-amd64.tar.gz" "${bindle_checksum}"
sudo tar zxvf bindle-${bindle_version}-linux-amd64.tar.gz -C /usr/local/bin
sudo chmod +x /usr/local/bin/bindle*
bindle --version
bindle-server --version

echo "Install Spin"
curl -sLO https://github.com/fermyon/spin/releases/download/${spin_version}/spin-${spin_version}-linux-amd64.tar.gz
validate-checksum "spin-${spin_version}-linux-amd64.tar.gz" "${spin_checksum}"
sudo tar zxvf spin-${spin_version}-linux-amd64.tar.gz -C /usr/local/bin
sudo chmod +x /usr/local/bin/spin
spin --version

echo "Install Hippo"
curl -sLO https://github.com/deislabs/hippo/releases/download/${hippo_version}/hippo-server-linux-x64.tar.gz
validate-checksum "hippo-server-linux-x64.tar.gz" "${hippo_checksum}"
mkdir -p /home/ubuntu/hippo
sudo tar zxvf hippo-server-linux-x64.tar.gz -C /home/ubuntu/hippo

# -----------------------------------------------------------------------------
# Configure deps
# -----------------------------------------------------------------------------

# Currently, config is setup via files in /home/ubuntu/etc and used in-line
# in the run_servers.sh script

# -----------------------------------------------------------------------------
# run-servers.sh or similar
# -----------------------------------------------------------------------------

cd /home/ubuntu
sudo chmod +x run_servers.sh

# Note: the basic_auth string will have '$' chars courtesy the bcrypt hashing of
# the password component, so we wrap in single quotes to avoid triggering the
# undefined variable bash check
export BASIC_AUTH='${basic_auth}'
export BASIC_AUTH_USERNAME="${basic_auth_username}"
export BASIC_AUTH_PASSWORD="${basic_auth_password}"
export HIPPO_REGISTRATION_MODE="${hippo_registration_mode}"

export DNS_ZONE="${dns_zone}"
export LETSENCRYPT_ENV="${letsencrypt_env}"

echo "Running servers using DNS zone '$DNS_ZONE' and Let's Encrypt env '$LETSENCRYPT_ENV'"
./run_servers.sh
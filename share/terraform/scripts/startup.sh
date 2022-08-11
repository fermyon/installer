#!/usr/bin/env bash
set -euo pipefail

# Output can be seen at:
# AWS: /var/log/cloud-init-output.log
# GCP: journalctl -u google-startup-scripts.service

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
mkdir -p ${home_path}/hippo
sudo tar zxvf hippo-server-linux-x64.tar.gz -C ${home_path}/hippo

echo "Install Hippo Theme - Fermyon"
curl -sLO https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/styles.css
curl -sLO https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/logo.svg
curl -sLO https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/config.json
curl -sLO https://www.fermyon.com/favicon.ico
mv styles.css ${home_path}/hippo/linux-x64/wwwroot/
mv config.json favicon.ico logo.svg ${home_path}/hippo/linux-x64/wwwroot/assets/

# -----------------------------------------------------------------------------
# Configure deps
# -----------------------------------------------------------------------------

# Currently, config is setup via files in ${home_path}/etc and used in-line
# in the run_servers.sh script

# -----------------------------------------------------------------------------
# run-servers.sh or similar
# -----------------------------------------------------------------------------

cd ${home_path}
sudo chmod +x run_servers.sh

export HIPPO_ADMIN_USERNAME='${hippo_admin_username}'
export HIPPO_ADMIN_PASSWORD='${hippo_admin_password}'
export HIPPO_REGISTRATION_MODE='${hippo_registration_mode}'
export HIPPO_FOLDER='${home_path}/hippo/linux-x64'

export DNS_ZONE='${dns_zone}'
export ENABLE_LETSENCRYPT='${enable_letsencrypt}'

echo "Running servers using DNS zone '$DNS_ZONE'"
./run_servers.sh

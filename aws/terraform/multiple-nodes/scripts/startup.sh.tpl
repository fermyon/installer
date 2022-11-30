#!/bin/bash
set -euo pipefail

# Output can be seen at:
# AWS: /var/log/cloud-init-output.log

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
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  unzip \
  wget \
  awscli \
  jq

## Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

## Install Hashistack & co deps

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update

${consul_install_snippet}

${nomad_install_snippet}

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
# run fermyon services
# -----------------------------------------------------------------------------

cd ${home_path}
sudo chmod +x run_servers.sh

export HOME_PATH='${home_path}'

export HIPPO_ADMIN_USERNAME='${hippo_admin_username}'
export HIPPO_ADMIN_PASSWORD='${hippo_admin_password}'
export HIPPO_REGISTRATION_MODE='${hippo_registration_mode}'
export HIPPO_FOLDER='${home_path}/hippo/linux-x64'

export DNS_ZONE='${dns_zone}'
export IP_ADDRESS='${public_ip}'
export ENABLE_LETSENCRYPT='${enable_letsencrypt}'

export REGION='${region}'
export BINDLE_VOLUME_ID='${bindle_volume_id}'

export IS_FIRST_SERVER=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)" --region ${region} | jq '.Tags[] | select(.Key == "IsFirstServer") | .Value')

if [ "$IS_FIRST_SERVER" == \"true\" ]; then
  echo "Running servers using DNS zone '$DNS_ZONE'"
  ./run_servers.sh
fi

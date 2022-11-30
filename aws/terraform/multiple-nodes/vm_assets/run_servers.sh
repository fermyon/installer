#!/bin/bash
set -euo pipefail

# Derived from https://github.com/fermyon/nomad-local-demo

export DNS_ZONE="${DNS_ZONE:-local.fermyon.link}"
export ENABLE_LETSENCRYPT="${ENABLE_LETSENCRYPT:-false}"
export INSTANCE_ID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)

if $ENABLE_LETSENCRYPT; then
  export PLATFORM_PROTOCOL="https"
else
  export PLATFORM_PROTOCOL="http"
fi

require() {
  if ! hash "$1" &>/dev/null; then
    echo "'$1' not found in PATH"
    exit 1
  fi
}

require nomad
require consul
require bindle-server

cleanup() {
  echo
  echo "Shutting down services"
  if [ ! -z $(jobs -p) ]; then
    kill $(jobs -p)
  fi
  wait
}

trap cleanup EXIT

nomad_run() {
  retry=0
  until [ "$retry" -ge 5 ]
  do
    nomad run $@ && break  # substitute your command here
    retry=$((retry+1))
    sleep 5
  done
}

echo "attach bindle volume"
aws ec2 attach-volume --device /dev/xvdb --instance-id ${INSTANCE_ID} --volume-id ${BINDLE_VOLUME_ID} --region ${REGION}
aws ec2 wait volume-in-use --volume-ids ${BINDLE_VOLUME_ID} --region ${REGION}
counter=0

echo "wait for /dev/xvdb ready"
while [ ! -e /dev/xvdb ]; do
  sleep 1
done

echo "mount /dev/xvdb to /bindle"
sudo mkfs -t ext4 /dev/xvdb
sudo mkdir /bindle
sudo mount -t ext4 -o defaults /dev/xvdb /bindle
sudo chown ubuntu:ubuntu /bindle

echo "unmount and detach bindle volume"
sudo umount /bindle
aws ec2 detach-volume --device /dev/xvdb --instance-id ${INSTANCE_ID} --volume-id ${BINDLE_VOLUME_ID} --region ${REGION}
aws ec2 wait volume-available --volume-ids ${BINDLE_VOLUME_ID} --region ${REGION}

echo "Starting traefik job..."
nomad_run job/traefik.nomad

echo "Starting aws-ebs csi job..."
nomad_run job/plugin-aws-ebs-controller.nomad
nomad_run job/plugin-aws-ebs-nodes.nomad

echo "Registing bindle volume..."
nomad volume register bindle-volume.hcl

echo "Registing postgres volume..."
nomad volume register postgres-volume.hcl

echo "Starting bindle job..."
nomad_run \
  -var domain="bindle.${DNS_ZONE}" \
  -var enable_letsencrypt="${ENABLE_LETSENCRYPT}" \
  job/bindle.nomad

echo "Starting postgres job..."
nomad_run job/postgres.nomad

echo "Starting hippo job..."
nomad_run \
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
echo "Consul:  http://${IP_ADDRESS}:8500"
echo "Nomad:   http://${IP_ADDRESS}:4646"
echo "Traefik: http://${IP_ADDRESS}:8081"
echo "Hippo:   ${PLATFORM_PROTOCOL}://hippo.${DNS_ZONE}"
echo
echo
echo "Export these into your shell"
echo
echo "    export CONSUL_HTTP_ADDR=http://${IP_ADDRESS}:8500"
echo "    export NOMAD_ADDR=http://${IP_ADDRESS}:4646"
echo "    export BINDLE_URL=${PLATFORM_PROTOCOL}://bindle.${DNS_ZONE}/v1"
echo "    export HIPPO_URL=${PLATFORM_PROTOCOL}://hippo.${DNS_ZONE}"
echo
echo "Ctrl+C to exit."
echo

wait

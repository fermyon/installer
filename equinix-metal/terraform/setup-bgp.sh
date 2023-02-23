#!/usr/bin/env bash
set -xueo pipefail

export DEBIAN_FRONTEND=noninteractive
apt update && apt install --yes jq

until jq -r -e ".bgp_neighbors" /tmp/metadata.json
do
  sleep 2
  # Refresh metadata until we have the information
  curl -o /tmp/metadata.json -fsSL https://metadata.platformequinix.com/metadata
done

cat >>/etc/network/interfaces <<EOF
auto lo:0
iface lo:0 inet static
  address ${global_ip}
  netmask 255.255.255.255
EOF

ifup lo:0

# Configure Routes
GATEWAY_IP=$(jq -r ".network.addresses[] | select(.public == false) | .gateway" /tmp/metadata.json)

for PEER_IP in $(jq -r ".bgp_neighbors[0].peer_ips[]" /tmp/metadata.json)
do
    ip route add $${PEER_IP} via $${GATEWAY_IP}
done

# Setup Bird
export DEBIAN_FRONTEND=noninteractive
apt update && apt install --yes python3-pip bird

cd /opt
git clone https://github.com/packethost/network-helpers.git

cd network-helpers
pip3 install jmespath
pip3 install -e .

./configure.py -r bird | tee /etc/bird/bird.conf
systemctl restart bird

until ls /root/job/hippo.nomad
do
  sleep 2
done

patch -u /root/job/hippo.nomad <<'EOF'
--- hippo.nomad 2023-02-23 13:37:17.867250648 +0000
+++ hippo.p     2023-02-23 13:37:37.811532752 +0000
@@ -69,14 +69,14 @@

       tags = var.enable_letsencrypt ? [
         "traefik.enable=true",
-        "traefik.http.routers.hippo.rule=Host(`$${var.domain}`)",
+        "traefik.http.routers.hippo.rule=HostRegexp(`$${var.domain}`, `hippo.{host:.+}`)",
         "traefik.http.routers.hippo.entryPoints=websecure",
         "traefik.http.routers.hippo.tls=true",
         "traefik.http.routers.hippo.tls.certresolver=letsencrypt-tls",
         "traefik.http.routers.hippo.tls.domains[0].main=$${var.domain}",
       ] : [
         "traefik.enable=true",
-        "traefik.http.routers.hippo.rule=Host(`$${var.domain}`)",
+        "traefik.http.routers.hippo.rule=HostRegexp(`$${var.domain}`, `hippo.{host:.+}`)",
         "traefik.http.routers.hippo.entryPoints=web",
       ]
EOF

patch -u /root/job/bindle.nomad <<'EOF'
--- bindle.nomad        2023-02-23 13:37:11.755161920 +0000
+++ bindle.p    2023-02-23 13:36:59.710983641 +0000
@@ -27,14 +27,14 @@

       tags = var.enable_letsencrypt ? [
         "traefik.enable=true",
-        "traefik.http.routers.bindle.rule=Host(`$${var.domain}`)",
+        "traefik.http.routers.bindle.rule=HostRegexp(`$${var.domain}`, `bindle.{host:.+}`)",
         "traefik.http.routers.bindle.entryPoints=websecure",
         "traefik.http.routers.bindle.tls=true",
         "traefik.http.routers.bindle.tls.certresolver=letsencrypt-tls",
         "traefik.http.routers.bindle.tls.domains[0].main=$${var.domain}",
       ]: [
         "traefik.enable=true",
-        "traefik.http.routers.bindle.rule=Host(`$${var.domain}`)",
+        "traefik.http.routers.bindle.rule=HostRegexp(`$${var.domain}`, `bindle.{host:.+}`)",
         "traefik.http.routers.bindle.entryPoints=web",
       ]
EOF

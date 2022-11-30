echo "Install Consul"
curl -sO https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
validate-checksum "consul_${consul_version}_linux_amd64.zip" "${consul_checksum}"
sudo unzip consul_${consul_version}_linux_amd64.zip -d /usr/local/bin
sudo chmod +x /usr/local/bin/consul
consul --version

useradd consul

cat <<SYSTEMD > "/lib/systemd/system/consul.service"
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
EnvironmentFile=-/etc/consul.d/consul.env
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SYSTEMD

# create folders
mkdir /etc/consul.d
chown consul:consul /etc/consul.d

mkdir /var/lib/consul
chown consul:consul /var/lib/consul

# Add the server config
cat <<HCL > "/etc/consul.d/consul.hcl"
{
  "server": true,
  "ui": true,
  "bootstrap_expect": ${consul_count},

  "data_dir": "/var/lib/consul",
  "retry_join": [
    "provider=aws tag_key=ConsulRole tag_value=consul-server addr_type=private_v4"
  ],
  "client_addr": "0.0.0.0",
  "bind_addr": "{{ GetPrivateInterfaces | include \"flags\" \"forwardable|up\" | attr \"address\" }}",
  "leave_on_terminate": true,
  "enable_syslog": true
}
HCL

systemctl enable consul
systemctl restart consul

# check consul ready
echo "Waiting for consul to come up..."
sleep 10
set +e
until [[ $(curl localhost:8500/v1/status/leader) != "No known Consul servers" ]]
do
  sleep 5
  echo "waiting for consul..."
done
set -e

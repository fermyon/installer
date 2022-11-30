echo "Install Nomad"
curl -sO https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip
validate-checksum "nomad_${nomad_version}_linux_amd64.zip" "${nomad_checksum}"
sudo unzip nomad_${nomad_version}_linux_amd64.zip -d /usr/local/bin
sudo chmod +x /usr/local/bin/nomad
nomad --version

cat <<SYSTEMD > "/lib/systemd/system/nomad.service"
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/nomad.d/nomad.env
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2

TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
SYSTEMD

# create folders
mkdir /etc/nomad.d
mkdir /var/lib/nomad

sudo mkdir -p /opt/bindle/data
sudo chown nobody:nogroup /opt/bindle/data

# TODO: split client to another auto scaling group
cat <<HCL > "/etc/nomad.d/nomad.hcl"
data_dir = "/var/lib/nomad"
bind_addr = "0.0.0.0"
leave_on_terminate = true
enable_syslog = true

server {
    # Use Consul to automatically cluster nodes
    # ref: https://learn.hashicorp.com/tutorials/nomad/clustering#use-consul-to-automatically-cluster-nodes
    enabled = true
    bootstrap_expect = ${nomad_count}
}

client {
    enabled = true
    template {
        disable_file_sandbox = true
    }
    
    host_volume "bindle" {
        path = "/opt/bindle/data"
        read_only = false
    }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

plugin "docker" {
  config {
    allow_privileged = true
  }
}
HCL

systemctl enable nomad
systemctl restart nomad

echo "Waiting for nomad..."
while ! nomad server members 2>/dev/null | grep -q alive; do
  sleep 2
done

cat <<EOM > "${home_path}/postgres-volume.hcl"
# volume registration
type = "csi"
id = "postgres"
name = "postgres"
external_id = "${aws_ebs_volume_postgres_id}"
access_mode = "single-node-writer"
attachment_mode = "file-system"
plugin_id = "aws-ebs0"
capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}
EOM

cat <<EON > "${home_path}/bindle-volume.hcl"
# volume registration
type = "csi"
id = "bindle"
name = "bindle"
external_id = "${aws_ebs_volume_bindle_id}"
access_mode = "single-node-writer"
attachment_mode = "file-system"
plugin_id = "aws-ebs0"
capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}
EON

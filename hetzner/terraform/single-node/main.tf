# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  dependencies = yamldecode(file("../../../share/terraform/dependencies.yaml"))
}

# -----------------------------------------------------------------------------
# Elastic IP to persist through instance restarts and serve as a known value
# for filling out DNS via chosen host, eg 44.194.137.14
# -----------------------------------------------------------------------------

resource "hcloud_floating_ip" "server" {
  type          = "ipv4"
  home_location = var.server_location
}

resource "hcloud_floating_ip_assignment" "server" {
  floating_ip_id = hcloud_floating_ip.server.id
  server_id      = hcloud_server.server.id
}

# -----------------------------------------------------------------------------
# Server config
# -----------------------------------------------------------------------------

resource "hcloud_server" "server" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.server_location
  image       = "ubuntu-20.04"
  ssh_keys    = [hcloud_ssh_key._.id]

  connection {
    host        = self.ipv4_address
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.ssh.private_key_pem
  }

  # Add config files, scripts, Nomad jobs to host
  provisioner "file" {
    source      = "../../../share/terraform/vm_assets/"
    destination = "/root"
  }

  # Advertise the floating IP address
  # See: https://discuss.hashicorp.com/t/cli-quick-start-guide-fails-on-hetzner-cloud-vps-server-when-binding-to-0-0-0-0/23014/4
  provisioner "remote-exec" {
    inline = [<<EOT
cat <<-EOF >> /root/etc/nomad.hcl
advertise {
  http = "${hcloud_floating_ip.server.ip_address}"
  rpc  = "${hcloud_floating_ip.server.ip_address}"
  serf = "${hcloud_floating_ip.server.ip_address}"
}
EOF
EOT
    ]
  }

  # Set up floating ip interface
  provisioner "remote-exec" {
    inline = [<<EOT
cat <<-EOF > /etc/netplan/60-floating-ip.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - ${hcloud_floating_ip.server.ip_address}/32
EOF
netplan apply;
    EOT
    ]
  }

  user_data = templatefile("../../../share/terraform/scripts/startup.sh",
    {
      home_path          = "/root"
      dns_zone           = var.dns_host == "sslip.io" ? "${hcloud_floating_ip.server.ip_address}.${var.dns_host}" : var.dns_host,
      enable_letsencrypt = var.enable_letsencrypt,

      nomad_version  = local.dependencies.nomad.version,
      nomad_checksum = local.dependencies.nomad.checksum,

      consul_version  = local.dependencies.consul.version,
      consul_checksum = local.dependencies.consul.checksum,

      vault_version  = local.dependencies.vault.version,
      vault_checksum = local.dependencies.vault.checksum,

      traefik_version  = local.dependencies.traefik.version,
      traefik_checksum = local.dependencies.traefik.checksum,

      bindle_version  = local.dependencies.bindle.version,
      bindle_checksum = local.dependencies.bindle.checksum,

      spin_version  = local.dependencies.spin.version,
      spin_checksum = local.dependencies.spin.checksum,

      hippo_version           = local.dependencies.hippo.version,
      hippo_checksum          = local.dependencies.hippo.checksum,
      hippo_registration_mode = var.hippo_registration_mode
      hippo_admin_username    = var.hippo_admin_username
      # TODO: ideally, Hippo will support ingestion of the admin password via
      # its hash (eg bcrypt, which Traefik and Bindle both support) - then we can remove
      # the need to pass the raw value downstream to the scripts, Nomad job, ecc.
      hippo_admin_password = random_password.hippo_admin_password.result,
    }
  )

}

# -----------------------------------------------------------------------------
# Firewall rules to specify allowed inbound/outbound addresses/ports
# -----------------------------------------------------------------------------

resource "hcloud_firewall" "allow_ssh_inbound" {
  count = length(var.allowed_ssh_cidr_blocks) > 0 ? 1 : 0
  name  = "allow_ssh_inbound"
  apply_to {
    server = hcloud_server.server.id
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    description = "Allow SSH inbound"
    source_ips  = var.allowed_ssh_cidr_blocks

  }
}

resource "hcloud_firewall" "allow_traefik_app_http_inbound" {
  count = !var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name  = "allow_traefik_app_http_inbound"
  apply_to {
    server = hcloud_server.server.id
  }
  rule {

    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    description = "Allow Traefik app HTTP inbound"
    source_ips  = var.allowed_inbound_cidr_blocks
  }
}

resource "hcloud_firewall" "allow_traefik_app_https_inbound" {
  count = var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name  = "allow_traefik_app_https_inbound"
  apply_to {
    server = hcloud_server.server.id
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    description = "Allow Traefik app HTTPS inbound"
    source_ips  = var.allowed_inbound_cidr_blocks

  }
}

resource "hcloud_firewall" "allow_nomad_api_inbound" {
  count = var.allow_inbound_http_nomad && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name  = "allow_nomad_api_inbound"
  apply_to {
    server = hcloud_server.server.id
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "4646"
    description = "Allow Nomad API inbound"
    source_ips  = var.allowed_inbound_cidr_blocks

  }
}

resource "hcloud_firewall" "allow_consul_api_inbound" {
  count = var.allow_inbound_http_consul && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name  = "allow_consul_api_inbound"
  apply_to {
    server = hcloud_server.server.id
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "8500"
    description = "Allow Consul API inbound"
    source_ips  = var.allowed_inbound_cidr_blocks
  }
}

# -----------------------------------------------------------------------------
# SSH keypair
# -----------------------------------------------------------------------------
resource "hcloud_ssh_key" "_" {
  name       = var.prefix
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "hetzner_ssh_key"
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.ssh.public_key_openssh
  filename        = "hetzner_ssh_key.pub"
  file_permission = "0600"
}


# -----------------------------------------------------------------------------
# Hippo admin password
# -----------------------------------------------------------------------------

resource "random_password" "hippo_admin_password" {
  length           = 22
  special          = true
  override_special = "!#%&*-_=+<>:?"
}

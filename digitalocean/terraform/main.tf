# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  dependencies = yamldecode(file("../../share/terraform/dependencies.yaml"))
}

# -----------------------------------------------------------------------------
# Default VPC
# -----------------------------------------------------------------------------

resource "digitalocean_vpc" "default" {
  name   = var.vpc_name
  region = var.region
}

# -----------------------------------------------------------------------------
# Reserved IP to persist through instance restarts and serve as a known value
# for filling out DNS via chosen host, eg 44.194.137.14
# -----------------------------------------------------------------------------

resource "digitalocean_reserved_ip" "lb" {
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "lb" {
  ip_address = digitalocean_reserved_ip.lb.ip_address
  droplet_id = digitalocean_droplet.droplet.id
}

# -----------------------------------------------------------------------------
# Droplet config
# -----------------------------------------------------------------------------

resource "digitalocean_droplet" "droplet" {
  image    = "ubuntu-20-04-x64"
  name     = var.droplet_name
  size     = var.droplet_size
  region   = var.region
  vpc_uuid = digitalocean_vpc.default.id
  ssh_keys = [digitalocean_ssh_key.droplet_ssh_keypair.fingerprint]

  # Add config files, scripts, Nomad jobs to host
  provisioner "file" {
    source      = "../../share/terraform/vm_assets/"
    destination = "/root"

    connection {
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.droplet_ssh_key.private_key_pem
    }
  }

  user_data = templatefile("../../share/terraform/scripts/startup.sh",
    {
      home_path          = "/root"
      dns_zone           = var.dns_host == "sslip.io" ? "${digitalocean_reserved_ip.lb.ip_address}.${var.dns_host}" : var.dns_host,
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

resource "digitalocean_firewall" "allow_ssh_inbound" {
  count       = length(var.allowed_ssh_cidr_blocks) > 0 ? 1 : 0
  name        = "allow-ssh-inbound"
  droplet_ids = [digitalocean_droplet.droplet.id]

  # ssh
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_cidr_blocks
  }
}

resource "digitalocean_firewall" "allow_traefik_app_http_inbound" {
  count       = !var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name        = "allow-traefik-app-http-inbound"
  droplet_ids = [digitalocean_droplet.droplet.id]

  # traefik app http
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = var.allowed_inbound_cidr_blocks
  }
}

resource "digitalocean_firewall" "allow_traefik_app_https_inbound" {
  count       = var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name        = "allow-traefik-app-https-inbound"
  droplet_ids = [digitalocean_droplet.droplet.id]

  # traefik app https
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = var.allowed_inbound_cidr_blocks
  }
}

resource "digitalocean_firewall" "allow_nomad_api_inbound" {
  count       = var.allow_inbound_http_nomad && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name        = "allow-nomad-api-inbound"
  droplet_ids = [digitalocean_droplet.droplet.id]

  # nomad api
  inbound_rule {
    protocol         = "tcp"
    port_range       = "4646"
    source_addresses = var.allowed_inbound_cidr_blocks
  }
}

resource "digitalocean_firewall" "allow_consul_api_inbound" {
  count       = var.allow_inbound_http_consul && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name        = "allow-consul-api-inbound"
  droplet_ids = [digitalocean_droplet.droplet.id]

  # consul api
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8500"
    source_addresses = var.allowed_inbound_cidr_blocks
  }
}

resource "digitalocean_firewall" "allow_all_outbound" {
  name        = "allow-all-outbound"
  droplet_ids = [digitalocean_droplet.droplet.id]

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = var.allow_outbound_cidr_blocks
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = var.allow_outbound_cidr_blocks
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = var.allow_outbound_cidr_blocks
  }
}

# -----------------------------------------------------------------------------
# SSH keypair
# -----------------------------------------------------------------------------

resource "tls_private_key" "droplet_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "digitalocean_ssh_key" "droplet_ssh_keypair" {
  name       = "${var.droplet_name}_ssh_key"
  public_key = tls_private_key.droplet_ssh_key.public_key_openssh
}

# -----------------------------------------------------------------------------
# Hippo admin password
# -----------------------------------------------------------------------------

resource "random_password" "hippo_admin_password" {
  length           = 22
  special          = true
  override_special = "!#%&*-_=+<>:?"
}

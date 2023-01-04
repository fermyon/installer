# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  dependencies = yamldecode(file("../../share/terraform/dependencies.yaml"))
}

# -----------------------------------------------------------------------------
# Default Network
# -----------------------------------------------------------------------------

resource "civo_network" "default" {
  label   = var.network_name
  region = var.region
}

# -----------------------------------------------------------------------------
# Reserved IP to persist through instance restarts and serve as a known value
# for filling out DNS via chosen host.
# -----------------------------------------------------------------------------

resource "civo_reserved_ip" "lb" {
  region = var.region
  name = "spin"
}

resource "civo_instance_reserved_ip_assignment" "lb" {
  reserved_ip_id = civo_reserved_ip.lb.id
  instance_id = civo_instance.spin.id
}

data "civo_disk_image" "ubuntu" {
   filter {
        key = "name"
        values = ["ubuntu-focal"]
   }
}
# -----------------------------------------------------------------------------
# Instance config
# -----------------------------------------------------------------------------
resource "civo_instance" "spin" {
  disk_image    = element(data.civo_disk_image.ubuntu.diskimages, 0).id
  hostname     = var.instance_name
  initial_user = "root"
  size     = var.instance_size
  region   = var.region
  network_id = civo_network.default.id
  firewall_id = civo_firewall.ingress_egress.id
  sshkey_id = civo_ssh_key.civo_ssh_keypair.id

  # Add config files, scripts, Nomad jobs to host
  provisioner "file" {
    source      = "../../share/terraform/vm_assets/"
    destination = "/root"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.civo_ssh_key.private_key_pem
    }
  }

  script = templatefile("../../share/terraform/scripts/startup.sh",
    {
      home_path          = "/root"
      dns_zone           = var.dns_host == "sslip.io" ? "${civo_reserved_ip.lb.ip}.${var.dns_host}" : var.dns_host,
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


resource "civo_firewall" "ingress_egress" {
  name        = "fermyon-firewall"
  network_id  = civo_network.default.id
  create_default_rules = false
  # traefik app https
   ingress_rule {
    action = "allow"
    protocol         = "tcp"
    port_range       = "22"
    cidr = var.allowed_inbound_cidr_blocks
  }
   ingress_rule {
    action = "allow"
    protocol         = "icmp"
    cidr = var.allowed_inbound_cidr_blocks
  }
  ingress_rule {
    action = "allow"
    protocol         = "tcp"
    port_range       = "80"
    cidr = var.allowed_inbound_cidr_blocks
  }
  ingress_rule {
    action = "allow"
    protocol         = "tcp"
    port_range       = "443"
    cidr = var.allowed_inbound_cidr_blocks
  }
  ingress_rule {
    action = "allow"
    protocol         = "tcp"
    port_range       = "4646"
    cidr = var.allowed_inbound_cidr_blocks
  }
  ingress_rule {
    action = "allow"
    protocol         = "tcp"
    port_range       = "8500"
    cidr = var.allowed_inbound_cidr_blocks
  }
  egress_rule {
    action = "allow"
    protocol              = "icmp"
    cidr = var.allow_outbound_cidr_blocks
  }

  egress_rule {
    action = "allow"
    protocol              = "tcp"
    port_range            = "1-65535"
    cidr = var.allow_outbound_cidr_blocks
  }

  egress_rule {
    action = "allow"
    protocol              = "udp"
    port_range            = "1-65535"
    cidr = var.allow_outbound_cidr_blocks
  }

}



# -----------------------------------------------------------------------------
# SSH keypair
# -----------------------------------------------------------------------------

resource "tls_private_key" "civo_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "civo_ssh_key" "civo_ssh_keypair" {
  name       = "${var.instance_name}_ssh_key"
  public_key = tls_private_key.civo_ssh_key.public_key_openssh
}

# -----------------------------------------------------------------------------
# Hippo admin password
# -----------------------------------------------------------------------------

resource "random_password" "hippo_admin_password" {
  length           = 22
  special          = true
  override_special = "!#%&*-_=+<>:?"
}

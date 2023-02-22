# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  dependencies = yamldecode(file("../../share/terraform/dependencies.yaml"))
}

# -----------------------------------------------------------------------------
# Reserved IP to persist through instance restarts and serve as a known value
# for filling out DNS via chosen host, eg 44.194.137.14
# -----------------------------------------------------------------------------

resource "equinix_metal_reserved_ip_block" "global_ip" {
  project_id = var.project_id
  type       = "global_ipv4"
  quantity   = 1
}

locals {
  # following expression will result to sth like "147.229.10.152/32"
  global_ip      = cidrhost(equinix_metal_reserved_ip_block.global_ip.cidr_notation, 0)
  global_ip_cidr = join("/", [cidrhost(equinix_metal_reserved_ip_block.global_ip.cidr_notation, 0), "32"])
}

resource "equinix_metal_ip_attachment" "global_ip_attach" {
  for_each      = toset(var.metros)
  device_id     = equinix_metal_device.fermyon[each.key].id
  cidr_notation = local.global_ip_cidr
}

# -----------------------------------------------------------------------------
# Server config
# -----------------------------------------------------------------------------

data "cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "bootstrap.sh"
    content_type = "text/x-shellscript"

    content = templatefile("${path.module}/setup-bgp.sh", {
      global_ip = local.global_ip
    })
  }

  part {
    filename     = "fermyon.sh"
    content_type = "text/x-shellscript"

    content = templatefile("../../share/terraform/scripts/startup.sh", {
      home_path          = "/root"
      dns_zone           = var.dns_host == "sslip.io" ? "${local.global_ip}.${var.dns_host}" : var.dns_host,
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
    })
  }
}

resource "equinix_metal_device" "fermyon" {
  for_each = toset(var.metros)
  metro    = each.key

  hostname         = var.server_name
  plan             = var.server_type
  operating_system = "ubuntu_20_04"
  billing_cycle    = "hourly"
  project_id       = var.project_id

  # Add config files, scripts, Nomad jobs to host
  provisioner "file" {
    source      = "../../share/terraform/vm_assets/"
    destination = "/root"

    connection {
      host        = self.access_public_ipv4
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.ssh_key.private_key_pem
    }
  }

  user_data = data.cloudinit_config.user_data.rendered
}

resource "equinix_metal_bgp_session" "bgp_session" {
  for_each = toset(var.metros)

  device_id      = equinix_metal_device.fermyon[each.key].id
  address_family = "ipv4"
}

# -----------------------------------------------------------------------------
# SSH keypair
# -----------------------------------------------------------------------------

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "equinix_metal_project_ssh_key" "ssh_keypair" {
  name       = "${var.server_name}-ssh-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
  project_id = var.project_id
}

# -----------------------------------------------------------------------------
# Hippo admin password
# -----------------------------------------------------------------------------

resource "random_password" "hippo_admin_password" {
  length           = 22
  special          = true
  override_special = "!#%&*-_=+<>:?"
}

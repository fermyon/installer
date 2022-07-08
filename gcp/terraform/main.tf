# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  dependencies = yamldecode(file("../../share/terraform/dependencies.yaml"))
}

# -----------------------------------------------------------------------------
# Default VPC
# -----------------------------------------------------------------------------

resource "google_compute_network" "default" {
  name = var.vpc_name

  depends_on = [google_project_service.compute]
}

# -----------------------------------------------------------------------------
# Standalone public IP to persist through instance restarts and serve as a known value
# for filling out DNS via chosen host, eg 44.194.137.14
# -----------------------------------------------------------------------------

resource "google_compute_address" "lb" {
  name = "${var.instance_name}-public-ip"

  depends_on = [google_project_service.compute]
}

# -----------------------------------------------------------------------------
# VM instance config
# -----------------------------------------------------------------------------

data "google_client_openid_userinfo" "me" {}

resource "google_service_account" "default" {
  account_id   = "${var.instance_name}-service-account"
  display_name = "${var.instance_name} Service Account"
}

resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  machine_type = var.instance_type

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = google_compute_network.default.name

    access_config {
      nat_ip = google_compute_address.lb.address
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  tags = ["allow-ssh", "allow-traefik-http", "allow-traefik-https", "allow-nomad-api", "allow-consul-api", "allow-all-outbound"] // firewall rules

  # Add config files, scripts, Nomad jobs to host
  provisioner "file" {
    source      = "../../share/terraform/vm_assets/"
    destination = "/home/${split("@", data.google_client_openid_userinfo.me.email)[0]}"

    connection {
      host        = google_compute_address.lb.address
      type        = "ssh"
      user        = split("@", data.google_client_openid_userinfo.me.email)[0]
      private_key = tls_private_key.vm_ssh_key.private_key_pem
    }
  }

  metadata = {
    ssh-keys = "${split("@", data.google_client_openid_userinfo.me.email)[0]}:${tls_private_key.vm_ssh_key.public_key_openssh}"
  }

  metadata_startup_script = templatefile("../../share/terraform/scripts/startup.sh",
    {
      home_path          = "/home/${split("@", data.google_client_openid_userinfo.me.email)[0]}"
      dns_zone           = var.dns_host == "sslip.io" ? "${google_compute_address.lb.address}.${var.dns_host}" : var.dns_host,
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

resource "google_compute_firewall" "allow_ssh_inbound" {
  count         = length(var.allowed_ssh_cidr_blocks) > 0 ? 1 : 0
  name          = "allow-ssh"
  network       = google_compute_network.default.name
  direction     = "INGRESS"
  target_tags   = ["allow-ssh"] // this targets our tagged VM
  source_ranges = var.allowed_ssh_cidr_blocks

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_traefik_app_http_inbound" {
  count         = !var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name          = "allow-traefik-http"
  network       = google_compute_network.default.name
  direction     = "INGRESS"
  target_tags   = ["allow-traefik-http"] // this targets our tagged VM
  source_ranges = var.allowed_inbound_cidr_blocks

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "allow_traefik_app_https_inbound" {
  count         = var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name          = "allow-traefik-https"
  network       = google_compute_network.default.name
  direction     = "INGRESS"
  target_tags   = ["allow-traefik-https"] // this targets our tagged VM
  source_ranges = var.allowed_inbound_cidr_blocks

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "allow_nomad_api_inbound" {
  count         = var.allow_inbound_http_nomad && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name          = "allow-nomad-api"
  network       = google_compute_network.default.name
  direction     = "INGRESS"
  target_tags   = ["allow-nomad-api"] // this targets our tagged VM
  source_ranges = var.allowed_inbound_cidr_blocks

  allow {
    protocol = "tcp"
    ports    = ["4646"]
  }
}

resource "google_compute_firewall" "allow_consul_api_inbound" {
  count         = var.allow_inbound_http_consul && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name          = "allow-consul-api"
  network       = google_compute_network.default.name
  direction     = "INGRESS"
  target_tags   = ["allow-consul-api"] // this targets our tagged VM
  source_ranges = var.allowed_inbound_cidr_blocks

  allow {
    protocol = "tcp"
    ports    = ["8500"]
  }
}

resource "google_compute_firewall" "allow_all_outbound" {
  name               = "allow-all-outbound"
  network            = google_compute_network.default.name
  direction          = "EGRESS"
  target_tags        = ["allow-all-outbound"] // this targets our tagged VM
  destination_ranges = var.allow_outbound_cidr_blocks

  allow {
    protocol = "all"
  }
}

# -----------------------------------------------------------------------------
# SSH keypair
# -----------------------------------------------------------------------------

resource "tls_private_key" "vm_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key_pem" {
  content         = tls_private_key.vm_ssh_key.private_key_pem
  filename        = ".ssh/${var.instance_name}_ssh_key_pair"
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

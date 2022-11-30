variable "domain" {
  type        = string
  default     = "bindle.local.fermyon.link"
  description = "hostname"
}

variable "enable_letsencrypt" {
  type    = bool
  default = "false"
  description = "Enable cert provisioning via Let's Encrypt"
}

job "bindle" {
  datacenters = ["dc1"]
  type        = "service"

  group "bindle" {
    count = 1

    network {
      port "http" {}
    }

    volume "bindle" {
      type            = "csi"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      source          = "bindle"
    }

    service {
      name = "bindle"
      port = "http"

      tags = var.enable_letsencrypt ? [
        "traefik.enable=true",
        "traefik.http.routers.bindle.rule=Host(`${var.domain}`)",
        "traefik.http.routers.bindle.entryPoints=websecure",
        "traefik.http.routers.bindle.tls=true",
        "traefik.http.routers.bindle.tls.certresolver=letsencrypt-tls",
        "traefik.http.routers.bindle.tls.domains[0].main=${var.domain}",
      ]: [
        "traefik.enable=true",
        "traefik.http.routers.bindle.rule=Host(`${var.domain}`)",
        "traefik.http.routers.bindle.entryPoints=web",
      ]

      check {
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "bindle" {
      driver = "docker"

      env {
        RUST_LOG = "error,bindle=debug"
        BINDLE_IP_ADDRESS_PORT = "0.0.0.0:${NOMAD_PORT_http}"
      }

      volume_mount {
        volume      = "bindle"
        destination = "/bindle-data"
        read_only   = false
      }

      config {
        # TODO: move the image version to dependencies.yaml
        image = "ghcr.io/fermyon/bindle:v0.8.2"
        ports = ["http"]
      }
    }
  }
}

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

variable "basic_auth_string" {
  type        = string
  description = "Basic auth string (e.g. <username>:<bcrypt hash of password>) for Bindle"
}

job "bindle" {
  datacenters = ["dc1"]
  type        = "service"

  group "bindle" {
    count = 1

    network {
      port "http" {}
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
      driver = "raw_exec"

      env {
        RUST_LOG = "error,bindle=debug"
      }

      template {
        data = var.basic_auth_string
        destination = "${NOMAD_TASK_DIR}/htpasswd"
      }

      config {
        command = "bindle-server"
        args = [
          "--htpasswd-file", "${NOMAD_TASK_DIR}/htpasswd",
          "--address", "${NOMAD_ADDR_http}",
          # PRO TIP: set to an absolute directory to persist bindles when job
          # is restarted
          "--directory", "${NOMAD_TASK_DIR}",
        ]
      }
    }
  }
}

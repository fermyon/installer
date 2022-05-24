variable "domain" {
  type        = string
  default     = "bindle.local.fermyon.link"
  description = "hostname"
}

variable "letsencrypt_env" {
  type    = string
  default = "staging"
  description = "The Let's Encrypt cert resolver to use. Options are 'staging' and 'prod'. (Default: staging)"

  validation {
    condition     = var.letsencrypt_env == "staging" || var.letsencrypt_env == "prod"
    error_message = "The Let's Encrypt env must be either 'staging' or 'prod'."
  }
}

variable "basic_auth" {
  type        = string
  description = "Basic auth username and password for authenticating with Bindle, eg user:<bcrypt_hash_of_password>"
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

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.bindle.rule=Host(`${var.domain}`)",
        "traefik.http.routers.bindle.entryPoints=websecure",
        "traefik.http.routers.bindle.tls=true",
        "traefik.http.routers.bindle.tls.certresolver=letsencrypt-tls-${var.letsencrypt_env}",
        "traefik.http.routers.bindle.tls.domains[0].main=${var.domain}",
        "traefik.http.routers.bindle.middlewares=basic-auth",
        "traefik.http.middlewares.basic-auth.basicauth.users=${var.basic_auth}",
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

      config {
        command = "bindle-server"
        args = [
          "--unauthenticated",
          "--address", "${NOMAD_IP_http}:${NOMAD_PORT_http}",
          # PRO TIP: set to an absolute directory to persist bindles when job
          # is restarted
          "--directory", "${NOMAD_TASK_DIR}",
        ]
      }
    }
  }
}

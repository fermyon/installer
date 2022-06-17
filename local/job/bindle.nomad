variable "domain" {
  type        = string
  default     = "local.fermyon.link"
  description = "hostname"
}

variable "os" {
  type        = string
  default     = "macos"
  description = "Operating system for downloading Bindle"
  validation {
    condition     = var.os == "macos" || var.os == "linux"
    error_message = "Invalid value for os; valid values are [macos, linux]."
  }
}

variable "arch" {
  type        = string
  default     = "amd64"
  description = "Architecture for downloading Bindle"
  validation {
    condition     = var.arch == "amd64" || var.arch == "aarch64"
    error_message = "Invalid value for arch; valid values are [amd64, aarch64]."
  }
}

job "bindle" {
  datacenters = ["dc1"]
  type        = "service"

  group "bindle" {
    count = 1

    network {
      port "http" {
        static = 8080
      }
    }

    service {
      name = "bindle"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.bindle.rule=Host(`bindle.${var.domain}`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "bindle" {
      driver = "raw_exec"

      artifact {
        source = lookup({
          linux="https://raw.githubusercontent.com/fermyon/installer/9fca2d7b641440cef0f75d38ace9cd3128b5a8a3/local/bindle/bindle-server"
        }, var.os, "https://bindle.blob.core.windows.net/releases/bindle-v0.8.0-${var.os}-${var.arch}.tar.gz")
      }

      env {
        RUST_LOG = "error,bindle=debug"
      }

      config {
        command = "bindle-server"
        args = [
          "--unauthenticated",
          "--address", "${NOMAD_ADDR_http}",
          # PRO TIP: set to an absolute directory to persist bindles when job
          # is restarted
          "--directory", "${NOMAD_TASK_DIR}",
        ]
      }
    }
  }
}

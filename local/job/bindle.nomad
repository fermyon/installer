variable "datacenters" {
  type = string
  default = "dc1"
  description = "a comma separated list of strings which determines which datacenters a service should be deployed to; i.e. \"dc1,dc2\".  String will be coerced to a list at evaluation."
}

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

variable "version" {
  default = "v0.8.2"
  description = "declares which release of bindle to target"
  type = string
}

job "bindle" {
  datacenters = split(",", var.datacenters)
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
        source = "https://bindle.blob.core.windows.net/releases/bindle-${var.version}-${var.os}-${var.arch}.tar.gz"
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

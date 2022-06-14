variable "domain" {
  type        = string
  default     = "local.fermyon.link"
  description = "hostname"
}

variable "bindle_url" {
  type        = string
  default     = "http://bindle.local.fermyon.link/v1"
  description = "The Bindle server URL"
}

variable "hippo_version" {
  type        = string
  default     = "v0.16.3"
  description = "Hippo version"
}

variable "os" {
  type        = string
  default     = "osx"
  description = "Operating system for downloading Hippo"
  validation {
    condition     = var.os == "osx" || var.os == "linux"
    error_message = "Invalid value for os; valid values are [osx, linux]."
  }
}

variable "driver" {
  type = string
  default = "raw_exec"
  validation {
    condition = var.driver == "raw_exec" || var.driver == "exec"
    error_message = "Invalid value for driver; valid values are [raw_exec, exec]."
  }
}

job "hippo" {
  datacenters = ["dc1"]
  type        = "service"

  group "hippo" {
    network {
      port "http" {
        static = 5309
      }
    }

    service {
      name = "hippo"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.hippo.rule=Host(`hippo.${var.domain}`)",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "hippo" {
      driver = var.driver

      artifact {
        source = "https://github.com/deislabs/hippo/releases/download/${var.hippo_version}/hippo-server-${var.os}-x64.tar.gz"
      }

      env {
        Hippo__PlatformDomain = var.domain
        Scheduler__Driver     = "nomad"

        Database__Driver            = "sqlite"
        ConnectionStrings__Database = "Data Source=hippo.db;Cache=Shared"

        Bindle__Url = var.bindle_url

        Jwt__Key      = "ceci n'est pas une jeton"
        Jwt__Issuer   = "localhost"
        Jwt__Audience = "localhost"

        Kestrel__Endpoints__Https__Url = "http://${NOMAD_ADDR_http}"
      }

      config {
        command = "bash"
        args    = ["-c", "cd local/${var.os}-x64 && ./Hippo.Web"]
      }
    }
  }
}

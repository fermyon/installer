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

variable "bindle_url" {
  type        = string
  default     = "http://bindle.local.fermyon.link/v1"
  description = "The Bindle server URL"
}

variable "hippo_version" {
  type        = string
  default     = "v0.20.2"
  description = "Hippo version"
}

variable "tags" {
  default = ""
  description = "a semicolon-separated list of tags to pass to Traefik"
  type = string
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

variable "registration_mode" {
  type    = string
  default = "AdministratorOnly"
  description = "The Hippo registration mode. Options are 'Open', 'Closed' and 'AdministratorOnly'. (Default: AdministratorOnly)"

  validation {
    condition     = var.registration_mode == "Open" || var.registration_mode == "Closed" || var.registration_mode == "AdministratorOnly"
    error_message = "The Hippo registration mode must be 'Open', 'Closed' or 'AdministratorOnly'."
  }
}

variable "arch" {
  default = "x64"
  description = "which architecture to use; available architectures varies by OS, but the only two available options are `x64` and `arm64`"
}

variable "admin_username" {
  type        = string
  description = "Username for the admin account"
  default     = null
}

variable "admin_password" {
  type        = string
  description = "Password for the admin account"
  default     = null
}

job "hippo" {
  datacenters = split(",", var.datacenters)
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

      tags = concat([
        "traefik.enable=true",
        "traefik.http.routers.hippo.rule=Host(`hippo.${var.domain}`)",
      ], split(";", var.tags))

      check {
        name     = "alive"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "hippo" {
      driver = "raw_exec"

      artifact {
        source = "https://github.com/deislabs/hippo/releases/download/${var.hippo_version}/hippo-server-${var.os}-${var.arch}.tar.gz"
      }

      artifact {
        source = "https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/styles.css"
      }

      artifact {
        source = "https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/logo.svg"
        destination = "local/${var.os}-${var.arch}/wwwroot/assets/"
      }

      artifact {
        source = "https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/config.json"
      }

      artifact {
        source = "https://www.fermyon.com/favicon.ico"
        destination = "local/${var.os}-${var.arch}/wwwroot/assets/"
      }

      env {
        Hippo__PlatformDomain = var.domain
        Scheduler__Driver     = "nomad"
        Nomad__Driver         = "raw_exec"

        # Registration configuration
        Hippo__RegistrationMode            = var.registration_mode
        Hippo__Administrators__0__Username = var.registration_mode == "AdministratorOnly" ? var.admin_username : ""
        Hippo__Administrators__0__Password = var.registration_mode == "AdministratorOnly" ? var.admin_password : ""

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
        args    = ["-c", "mv local/styles.css local/${var.os}-${var.arch}/wwwroot/ && mv local/config.json local/${var.os}-${var.arch}/wwwroot/assets/ && cd local/${var.os}-${var.arch} && ./Hippo.Web"]
      }
    }
  }
}

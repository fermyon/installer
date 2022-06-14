variable "domain" {
  type        = string
  default     = "hippo.local.fermyon.link"
  description = "hostname"
}

variable "bindle_url" {
  type        = string
  default     = "http://bindle.local.fermyon.link/v1"
  description = "The Bindle server URL"
}

variable "enable_letsencrypt" {
  type    = bool
  default = "false"
  description = "Enable cert provisioning via Let's Encrypt"
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
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  group "hippo" {
    count = 1

    network {
      port "http" {
        static = 5000
      }
    }

    service {
      name = "hippo"
      port = "http"

      tags = var.enable_letsencrypt ? [
        "traefik.enable=true",
        "traefik.http.routers.hippo.rule=Host(`${var.domain}`)",
        "traefik.http.routers.hippo.entryPoints=websecure",
        "traefik.http.routers.hippo.tls=true",
        "traefik.http.routers.hippo.tls.certresolver=letsencrypt-tls",
        "traefik.http.routers.hippo.tls.domains[0].main=${var.domain}",
      ] : [
        "traefik.enable=true",
        "traefik.http.routers.hippo.rule=Host(`${var.domain}`)",
        "traefik.http.routers.hippo.entryPoints=web",
      ]

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
        source = "https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/styles.css"
      }

      artifact {
        source = "https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/logo.svg"
        destination = "/home/ubuntu/hippo/linux-x64/wwwroot/assets/"
      }

      artifact {
        source = "https://gist.githubusercontent.com/bacongobbler/48dc7b01aa99fa4b893eeb6b62f8cd27/raw/fb4dae8f42bc6aea22b2566084d01fa0de845e7c/config.json"
      }

      artifact {
        source = "https://www.fermyon.com/favicon.ico"
        destination = "/home/ubuntu/hippo/linux-x64/wwwroot/assets/"
      }

      env {
        # Enable for debug logging
        # Logging__LogLevel__Default = "Debug"

        Hippo__PlatformDomain = var.domain
        Scheduler__Driver     = "nomad"

        # Registration configuration
        Hippo__RegistrationMode            = var.registration_mode
        Hippo__Administrators__0__Username = var.registration_mode == "AdministratorOnly" ? var.admin_username : ""
        Hippo__Administrators__0__Password = var.registration_mode == "AdministratorOnly" ? var.admin_password : ""

        # Database Driver: inmemory, sqlite, postgresql
        Database__Driver            = "sqlite"
        ConnectionStrings__Database = "Data Source=hippo.db;Cache=Shared"

        # Database__Driver            = "postgresql"
        # ConnectionStrings__Database = "Host=localhost;Username=postgres;Password=postgres;Database=hippo"

        ConnectionStrings__Bindle     = "server=${var.bindle_url}"

        Nomad__Traefik__Entrypoint   = var.enable_letsencrypt ? "websecure" : "web"
        Nomad__Traefik__CertResolver = var.enable_letsencrypt ? "letsencrypt-tls" : ""

        Jwt__Key      = "ceci n'est pas une jeton"
        Jwt__Issuer   = "localhost"
        Jwt__Audience = "localhost"

        Kestrel__Endpoints__Https__Url = "http://${NOMAD_ADDR_http}"
      }

      config {
        command = "bash"
        args    = ["-c", "mv local/styles.css /home/ubuntu/hippo/linux-x64/wwwroot/ && mv local/config.json /home/ubuntu/hippo/linux-x64/wwwroot/assets/ &&cd /home/ubuntu/hippo/linux-x64 && ./Hippo.Web"]
      }
    }
  }
}

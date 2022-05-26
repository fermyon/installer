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

variable "letsencrypt_env" {
  type    = string
  default = "staging"
  description = "The Let's Encrypt cert resolver to use. Options are 'staging' and 'prod'. (Default: staging)"

  validation {
    condition     = var.letsencrypt_env == "staging" || var.letsencrypt_env == "prod"
    error_message = "The Let's Encrypt env must be either 'staging' or 'prod'."
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

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.hippo.rule=Host(`${var.domain}`)",
        "traefik.http.routers.hippo.entryPoints=websecure",
        "traefik.http.routers.hippo.tls=true",
        "traefik.http.routers.hippo.tls.certresolver=letsencrypt-tls-${var.letsencrypt_env}",
        "traefik.http.routers.hippo.tls.domains[0].main=${var.domain}",
        "traefik.http.routers.hippo.middlewares=basic-auth",
        "traefik.http.middlewares.basic-auth.basicauth.users=${var.basic_auth}",
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

      env {
        Hippo__PlatformDomain = var.domain
        Scheduler__Driver     = "nomad"

        # Registration configuration
        Hippo__RegistrationMode            = var.administration_mode
        Hippo__Administrators__0__Username = var.administration_mode == "AdministratorOnly" ? var.admin_username : ""
        Hippo__Administrators__0__Password = var.administration_mode == "AdministratorOnly" ? var.admin_password : ""

        # Database Driver: inmemory, sqlite, postgresql
        Database__Driver            = "sqlite"
        ConnectionStrings__Database = "Data Source=hippo.db;Cache=Shared"

        # Database__Driver            = "postgresql"
        # ConnectionStrings__Database = "Host=localhost;Username=postgres;Password=postgres;Database=hippo"

        Bindle__Url = var.bindle_url

        Nomad__Traefik__Entrypoint   = "websecure"
        Nomad__Traefik__CertResolver = "letsencrypt-tls-${var.letsencrypt_env}"

        Jwt__Key      = "ceci n'est pas une jeton"
        Jwt__Issuer   = "localhost"
        Jwt__Audience = "localhost"

        Kestrel__Endpoints__Https__Url = "http://${NOMAD_IP_http}:${NOMAD_PORT_http}"
      }

      config {
        command = "bash"
        args    = ["-c", "cd /home/ubuntu/hippo/linux-x64 && ./Hippo.Web"]
      }
    }
  }
}

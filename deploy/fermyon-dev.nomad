variable "region" {
  type    = string
}

variable "production" {
  type        = bool
  default     = false
  description = "Whether or not this job should run in production mode. Default: false."
}

variable "dns_domain" {
  type        = string
  default     = "fermyon.dev"
  description = "The DNS domain for the Fermyon Platform website."
}

variable "letsencrypt_env" {
  type    = string
  default = "prod"
  description = <<EOF
The Let's Encrypt cert resolver to use. Options are 'staging' and 'prod'. (Default: prod)

With the letsencrypt-prod cert resolver, we're limited to *5 requests per week* for a cert with matching domain and SANs.
For testing/staging, it is recommended to use letsencrypt-staging, which has vastly increased limits.
EOF

  validation {
    condition     = var.letsencrypt_env == "staging" || var.letsencrypt_env == "prod"
    error_message = "The Let's Encrypt env must be either 'staging' or 'prod'."
  }
}

variable "bindle_id" {
  type        = string
  default     = "fermyon.dev/0.1.0"
  description = "A bindle id, such as foo/bar/1.2.3"
}

job "fermyon-dev" {
  type = "service"
  datacenters = [
    "${var.region}a",
    "${var.region}b",
    "${var.region}c",
    "${var.region}d",
    "${var.region}e",
    "${var.region}f"
  ]

  group "fermyon-dev" {
    count = 3

    update {
      max_parallel      = 1
      canary            = 3
      min_healthy_time  = "10s"
      healthy_deadline  = "10m"
      progress_deadline = "15m"
      auto_revert       = true
      auto_promote      = true
    }

    network {
      port "http" {}
    }

    service {
      name = "fermyon-dev-${NOMAD_NAMESPACE}"
      port = "http"

      tags = var.production ? [
        # Prod config
        #
        "traefik.enable=true",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.rule=Host(`${var.dns_domain}`, `www.${var.dns_domain}`)",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.entryPoints=websecure",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.tls=true",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.tls.certresolver=letsencrypt-cf-${var.letsencrypt_env}",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.tls.domains[0].main=www.${var.dns_domain}",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.tls.domains[1].main=${var.dns_domain}",
        # NOTE: middleware name MUST be unique across a given namespace.
        # If there are duplicates, Traefik errors out and each site using the
        # duplicated name will not be routed to (404).
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.middlewares=fermyon-dev-www-redirect",
        "traefik.http.middlewares.fermyon-dev-www-redirect.redirectregex.regex=^https?://${var.dns_domain}/(.*)",
        "traefik.http.middlewares.fermyon-dev-www-redirect.redirectregex.replacement=https://www.${var.dns_domain}/$${1}",
        "traefik.http.middlewares.fermyon-dev-www-redirect.redirectregex.permanent=true",
      ] : [
        # Staging config
        #
        "traefik.enable=true",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.rule=Host(`canary.${var.dns_domain}`)",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.entryPoints=websecure",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.tls=true",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.tls.certresolver=letsencrypt-cf-${var.letsencrypt_env}",
        "traefik.http.routers.fermyon-dev-${NOMAD_NAMESPACE}.tls.domains[0].main=canary.${var.dns_domain}"
      ]

      check {
        type     = "http"
        path     = "/.well-known/spin/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "exec"

      artifact {
        source = "https://github.com/fermyon/spin/releases/download/v0.8.0/spin-v0.8.0-linux-amd64.tar.gz"
        options {
          checksum = "sha256:0ef31fe6e2b4d34ddd089b01a1f88820f88c456276bfe4e1477836a6087654c1"
        }
      }

      env {
        RUST_LOG   = "spin=trace"
        BINDLE_URL = "http://bindle.service.consul:3030/v1"
        BASE_URL   = var.production ? "https://www.${var.dns_domain}" : "https://canary.${var.dns_domain}"
      }

      config {
        command = "spin"
        args = [
          "up",
          "--listen", "${NOMAD_IP_http}:${NOMAD_PORT_http}",
          "--bindle", var.bindle_id,
          "--log-dir", "${NOMAD_ALLOC_DIR}/logs",
          "--temp", "${NOMAD_ALLOC_DIR}/tmp",

          # Set BASE_URL for Bartholomew to override default (localhost:3000)
          "-e", "BASE_URL=${BASE_URL}",
        ]
      }
    }
  }
}

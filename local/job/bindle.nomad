variable "domain" {
  type        = string
  default     = "local.fermyon.link"
  description = "hostname"
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

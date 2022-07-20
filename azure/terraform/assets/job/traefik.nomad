job "traefik" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 80
      }

      port "https" {
        static = 443
      }

      port "api" {
        static = 8081
      }
    }

    service {
      name = "traefik"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "raw_exec"

      config {
        command = "traefik"
        args = [
          "--configfile", "local/traefik.toml"
        ]
      }

      template {
        data = <<EOF
[log]
  level = "DEBUG"

[entryPoints]
  [entryPoints.web]
    address = ":80"

  [entryPoints.websecure]
    address = ":443"
    [entryPoints.websecure.http.tls]

  [entryPoints.traefik]
    address = ":8081"

# Let's Encrypt TLS
[certificatesResolvers.letsencrypt-tls.acme]
  # Supply an email to get cert expiration notices
  # email = "you@example.com"
  # The CA server can be toggled to staging for testing/avoiding rate limits
  # caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
  storage = "/acme.json"
  [certificatesResolvers.letsencrypt-tls.acme.tlsChallenge]

[api]
    dashboard = true
    insecure  = true

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"
EOF

        destination = "local/traefik.toml"
      }

    }
  }
}

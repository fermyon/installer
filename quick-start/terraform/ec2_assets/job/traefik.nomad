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
    [entryPoints.web.http]
      [entryPoints.web.http.redirections]
        [entryPoints.web.http.redirections.entryPoint]
          to = "websecure"
          scheme = "https"

  [entryPoints.websecure]
    address = ":443"
    [entryPoints.websecure.http.tls]

  [entryPoints.traefik]
    address = ":8081"

# Let's Encrypt TLS
[certificatesResolvers.letsencrypt-tls-staging.acme]
  email = "fermyon-hashistack-demo@fermyon.dev"
  storage = "/acme.json"
  caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
  [certificatesResolvers.letsencrypt-tls-staging.acme.tlsChallenge]

[certificatesResolvers.letsencrypt-tls-prod.acme]
  email = "fermyon-hashistack-demo@fermyon.dev"
  storage = "/acme.json"
  [certificatesResolvers.letsencrypt-tls-prod.acme.tlsChallenge]

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

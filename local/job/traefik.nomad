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

      port "api" {
        static = 8081
      }
    }

    service {
      name     = "traefik"
      provider = "nomad"
    }

    task "traefik" {
      driver = "raw_exec"

      artifact {
        source = "https://github.com/traefik/traefik/releases/download/v2.8.0/traefik_v2.8.0_${attr.kernel.name}_${attr.cpu.arch}.tar.gz"
      }

      config {
        command = "traefik"
        args = [
          "--configfile", "local/traefik.toml"
        ]
      }

      template {
        data = <<EOF
[entryPoints]
    [entryPoints.http]
    address = ":80"
    [entryPoints.traefik]
    address = ":8081"

[api]
    dashboard = true
    insecure  = true

[providers.nomad]
  [providers.nomad.endpoint]
    address = "http://127.0.0.1:4646"
EOF

        destination = "local/traefik.toml"
      }

    }
  }
}

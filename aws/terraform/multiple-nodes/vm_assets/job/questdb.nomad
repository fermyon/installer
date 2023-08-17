job "questdb" {
  datacenters = ["dc1"]
  type        = "service"

  group "questdb" {
    count = 1

    volume "postgres" {
      type            = "csi"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      source          = "questdb"
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "questdb" {
      driver = "docker"

      volume_mount {
        volume      = "questdb"
        destination = "/var/lib/questdb/data"
        read_only   = false
      }

      env = {
        "POSTGRES_PASSWORD" = "questdb"
        "POSTGRES_DB"       = "hippo"
        "PGDATA"            = "/var/lib/questdb/data/hippo/"
      }

      config {
        image = "questdb/questdb"

        ports = ["db",  "lb"]
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "questdb"
        port = "db"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
    network {
      port "db" {
        static = 9000
      }
      # Mapped ports
      port "http"  { to = 80 }
      port "https" { to = 443 }
      # Static ports
      port "lb" { static = 8080 }

    }
  }
}

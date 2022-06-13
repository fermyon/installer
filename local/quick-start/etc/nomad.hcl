log_level            = "INFO"
disable_update_check = true

# these settings allow Nomad to automatically find its peers through Consul
consul {
  server_service_name = "nomad"
  server_auto_join    = true
  client_service_name = "nomad-client"
  client_auto_join    = true
  auto_advertise      = true
}

server {
  enabled          = true
  bootstrap_expect = 1
}

client {
  options = {
    "driver.blacklist" = "java"
  }
}

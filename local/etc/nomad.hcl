log_level            = "INFO"
disable_update_check = true

server {
  enabled          = true
  bootstrap_expect = 1
}

client {
  options = {
    "driver.blacklist" = "java"
  }
}

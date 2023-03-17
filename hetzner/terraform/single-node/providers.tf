terraform {
  required_version = ">= 1.0.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.36.2"
    }
  }
}


# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

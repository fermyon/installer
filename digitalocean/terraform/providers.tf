terraform {
  required_version = ">= 1.0.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "3.4.0"
    }
  }
}

provider "digitalocean" {
}

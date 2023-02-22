terraform {
  required_version = ">= 1.0.0"

  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = "~> 1.12"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "3.4.0"
    }
  }
}

provider "equinix" {}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
civo = {
      source = "civo/civo"
      version = "1.0.28"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "3.4.0"
    }
  }
}

provider "civo" {
}

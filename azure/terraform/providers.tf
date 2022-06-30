terraform {
    required_version = ">= 1.0.0"

    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "~>3.0"
        }
    }
}

provider "azurerm" {
    features {}

    subscription_id = "dfb5d696-98d8-447c-a14d-56f131f3c4a5"
    tenant_id = "72f988bf-86f1-41af-91ab-2d7cd011db47"
    client_id = "8ea5e1e0-a64f-4073-842f-07156f7b57b6"
    client_secret = "BhGtcElLrC0lmGCy.UmazKs.1DV-1zZC13" 
}
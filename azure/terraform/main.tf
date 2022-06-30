# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  nomad_version    = "1.3.1"
  nomad_checksum   = "d16dcea9fdfab3846e749307e117e33a07f0d8678cf28cc088637055e34e5b37"

  consul_version   = "1.12.1"
  consul_checksum  = "8d138267701fc3502dc6b01beb08ae8fac969022ab867f61bc945af38686ecc3"

  vault_version    = "1.10.3"
  vault_checksum   = "c99aeefd30dbeb406bfbd7c80171242860747b3bf9fa377e7a9ec38531727f31"

  traefik_version  = "v2.7.0"
  traefik_checksum = "348e444c390156a3d17613e421ec80e23874e2388ef0cc22d7ad00a5b9c7f21a"

  bindle_version   = "v0.8.0"
  bindle_checksum  = "26f68ab5a03c7e6f0c8b83fb199ca77244c834f25247b9a62312eb7a89dba93c"

  spin_version     = "v0.2.0"
  spin_checksum    = "f5c25a7f754ef46dfc4b2361d6f34d40564768a60d7bc0d183dc26fe1bdcfae0"

  hippo_version    = "v0.17.0"
  hippo_checksum   = "2a9690cd8546108fbd27a9f0c4898d1c2c171a76219803290b526e40da1c3211"

  common_tags = {
    FermyonInstallation = "localtest"
  }
}

# -----------------------------------------------------------------------------
# Azure Resource Group Defaults
# -----------------------------------------------------------------------------
resource "random_pet" "rg-name" {
    prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
    name = random_pet.rg-name.id
    location = var.resource_group_location
}

# -----------------------------------------------------------------------------
# Azure VNET, Subnet, IP, DNS Zone
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "default" {
    name = "${var.vm_name}-vnet"
    address_space = ["10.0.0.0/16"]
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "defaultsubnet" {
    name = "${var.vm_name}-subnet"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.default.name
    address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "defaultIp" {
    name = "${var.vm_name}-pip"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method = "Static"
}

# -----------------------------------------------------------------------------
# Azure NSG
# -----------------------------------------------------------------------------
resource "azurerm_network_security_group" "defaultnsg" {
    name = "${var.vm_name}-nsg"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    security_rule {
        name = "SSH"
        priority = 1001
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "HTTP"
        priority = 1002
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "80"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "HTTPS"
        priority = 1003
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "443"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
}


# -----------------------------------------------------------------------------
# Azure Network Interface
# -----------------------------------------------------------------------------
resource "azurerm_network_interface" "defaultnic" {
    name = "${var.vm_name}-nic"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    ip_configuration {
        name                          = "defaultNicConfig"
        subnet_id                     = azurerm_subnet.defaultsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.defaultIp.id
  }
}

# Connect SG to NIC
resource "azurerm_network_interface_security_group_association" "defaultnicsg" {
    network_interface_id = azurerm_network_interface.defaultnic.id
    network_security_group_id = azurerm_network_security_group.defaultnsg.id
}

# -----------------------------------------------------------------------------
# Azure Storage
# -----------------------------------------------------------------------------
resource "random_id" "randomID" {
    keepers = {
        # Generate new ID only when new resource group is defined
        resource_group = azurerm_resource_group.rg.name
    }

    byte_length = 8
}

resource "azurerm_storage_account" "defaultstorage" {
    name = "diag${random_id.randomID.hex}"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    account_tier = "Standard"
    account_replication_type = "LRS"
}

# -----------------------------------------------------------------------------
# SSH Key
# -----------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "azurerm_ssh_public_key" "ssh_public_key" {
    name = "${var.vm_name}_ssh_public_key"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    public_key = tls_private_key.ssh.public_key_openssh

    tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Azure VM
# -----------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "defaultVM" {
    name = var.vm_name
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    network_interface_ids = [azurerm_network_interface.defaultnic.id]
    size = var.vm_sku

    os_disk {
      name = "myFermyonDisk"
      caching = "ReadWrite"
      storage_account_type = "Premium_LRS"
    }

    source_image_reference {
      publisher = "Canonical"
      offer = "0001-com-ubuntu-server-focal"
      sku = "20_04-lts-gen2"
      version = "latest"
    }

    computer_name = "myfermyonvm"
    admin_username = "ubuntu"
    disable_password_authentication = true

    admin_ssh_key {
      username = "ubuntu"
      public_key = tls_private_key.ssh.public_key_openssh
    }

    boot_diagnostics {
      storage_account_uri = azurerm_storage_account.defaultstorage.primary_blob_endpoint
    }

    # Add config files, scripts, Nomad jobs to host
    provisioner "file" {
        source      = "${path.module}/assets/"
        destination = "/home/ubuntu"

        connection {
            host        = azurerm_public_ip.defaultIp.ip_address
            type        = "ssh"
            user        = "ubuntu"
            private_key = tls_private_key.ssh.private_key_pem
        }
    }

    user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh",
    {
      dns_zone                = var.dns_host == "sslip.io" ? "${azurerm_public_ip.defaultIp.ip_address}.${var.dns_host}" : var.dns_host,
      enable_letsencrypt      = var.enable_letsencrypt,

      nomad_version           = local.nomad_version,
      nomad_checksum          = local.nomad_checksum,

      consul_version          = local.consul_version,
      consul_checksum         = local.consul_checksum,

      vault_version           = local.vault_version,
      vault_checksum          = local.vault_checksum,

      traefik_version         = local.traefik_version,
      traefik_checksum        = local.traefik_checksum,

      bindle_version          = local.bindle_version,
      bindle_checksum         = local.bindle_checksum,

      spin_version            = local.spin_version,
      spin_checksum           = local.spin_checksum,

      hippo_version           = local.hippo_version,
      hippo_checksum          = local.hippo_checksum,
      hippo_registration_mode = var.hippo_registration_mode
      hippo_admin_username    = var.hippo_admin_username
      # TODO: ideally, Hippo will support ingestion of the admin password via
      # its hash (eg bcrypt, which Traefik and Bindle both support) - then we can remove
      # the need to pass the raw value downstream to the scripts, Nomad job, ecc.
      hippo_admin_password    = random_password.hippo_admin_password.result,
    }
  ))
}



# -----------------------------------------------------------------------------
# Hippo admin password
# -----------------------------------------------------------------------------

resource "random_password" "hippo_admin_password" {
  length           = 22
  special          = true
  override_special = "!#%&*-_=+<>:?"
}

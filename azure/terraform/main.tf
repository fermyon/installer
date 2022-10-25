# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

# TODO: use the shared dependency versions/checksums at share/terraform/dependencies.yaml instead
locals {
  nomad_version  = "1.4.1"
  nomad_checksum = "f9327818a97fc2f29b6a9283c3175cd13ba6c774c15ee5683035c23b9a3640fa"

  consul_version  = "1.13.3"
  consul_checksum = "5370b0b5bf765530e28cb80f90dcb47bd7d6ba78176c1ab2430f56e460ed279c"

  vault_version  = "1.12.0"
  vault_checksum = "56d140b34bec780cd458672e39b3bb0ea9e4b7e4fb9ea7e15de31e1562130d7a"

  traefik_version  = "v2.9.1"
  traefik_checksum = "562f3c57b6a1fe381e65cd46e6deb0ac6f0ad8f2e277748262814f4c5ef65861"

  bindle_version  = "v0.8.0"
  bindle_checksum = "2b1d5c8fbd10684147e3546de1c2dcd438e691441ea68ca32c23a4d1c1d81048"

  spin_version  = "v0.6.0"
  spin_checksum = "fd613b75f0fdc1708d77ca18512b923d24603d4af103a74038815441ddd11573"

  hippo_version  = "v0.19.1"
  hippo_checksum = "46f53d44a8995453cee51ad5e9c129d30de279b9a4f8d12980b4aa805ec23054"

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
  name     = random_pet.rg-name.id
  location = var.resource_group_location
}

# -----------------------------------------------------------------------------
# Azure VNET, Subnet, IP
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "default" {
  name                = "${var.vm_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "defaultsubnet" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "defaultIp" {
  name                = "${var.vm_name}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# -----------------------------------------------------------------------------
# Azure NSG
# -----------------------------------------------------------------------------
resource "azurerm_network_security_group" "defaultnsg" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_ssh_inbound" {
  count                       = length(var.allowed_ssh_cidr_blocks) > 0 ? 1 : 0
  name                        = "Allow SSH Inbound"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ssh_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.defaultnsg.name
}

resource "azurerm_network_security_rule" "allow_traefik_app_http_inbound" {
  count                       = !var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name                        = "Allow Traefik App HTTP Inbound"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = var.allowed_inbound_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.defaultnsg.name
}

resource "azurerm_network_security_rule" "allow_traefik_app_https_inbound" {
  count                       = var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name                        = "Allow Traefik App HTTPS Inbound"
  priority                    = 1003
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.allowed_inbound_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.defaultnsg.name
}

resource "azurerm_network_security_rule" "allow_nomad_api_inbound" {
  count                       = var.allow_inbound_http_nomad && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name                        = "Allow Nomad API inbound"
  priority                    = 1004
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "4646"
  source_address_prefixes     = var.allowed_inbound_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.defaultnsg.name
}

resource "azurerm_network_security_rule" "allow_consul_api_inbound" {
  count                       = var.allow_inbound_http_consul && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  name                        = "Allow Consul API inbound"
  priority                    = 1005
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8500"
  source_address_prefixes     = var.allowed_inbound_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.defaultnsg.name
}

resource "azurerm_network_security_rule" "allow_all_outbound" {
  name                        = "Allow All Outbound"
  priority                    = 1001
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.allow_outbound_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.defaultnsg.name
}

# -----------------------------------------------------------------------------
# Azure Network Interface
# -----------------------------------------------------------------------------
resource "azurerm_network_interface" "defaultnic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.rg.location
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
  network_interface_id      = azurerm_network_interface.defaultnic.id
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
  name                     = "diag${random_id.randomID.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# -----------------------------------------------------------------------------
# SSH Key
# -----------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_ssh_public_key" "ssh_public_key" {
  name                = "${var.vm_name}_ssh_public_key"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  public_key          = tls_private_key.ssh.public_key_openssh

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Azure VM
# -----------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "defaultVM" {
  name                  = var.vm_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.defaultnic.id]
  size                  = var.vm_sku

  os_disk {
    name                 = "${var.vm_name}-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "myfermyonvm"
  admin_username                  = "ubuntu"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "ubuntu"
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
      dns_zone           = var.dns_host == "sslip.io" ? "${azurerm_public_ip.defaultIp.ip_address}.${var.dns_host}" : var.dns_host,
      enable_letsencrypt = var.enable_letsencrypt,

      nomad_version  = local.nomad_version,
      nomad_checksum = local.nomad_checksum,

      consul_version  = local.consul_version,
      consul_checksum = local.consul_checksum,

      vault_version  = local.vault_version,
      vault_checksum = local.vault_checksum,

      traefik_version  = local.traefik_version,
      traefik_checksum = local.traefik_checksum,

      bindle_version  = local.bindle_version,
      bindle_checksum = local.bindle_checksum,

      spin_version  = local.spin_version,
      spin_checksum = local.spin_checksum,

      hippo_version           = local.hippo_version,
      hippo_checksum          = local.hippo_checksum,
      hippo_registration_mode = var.hippo_registration_mode
      hippo_admin_username    = var.hippo_admin_username
      # TODO: ideally, Hippo will support ingestion of the admin password via
      # its hash (eg bcrypt, which Traefik and Bindle both support) - then we can remove
      # the need to pass the raw value downstream to the scripts, Nomad job, ecc.
      hippo_admin_password = random_password.hippo_admin_password.result,
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

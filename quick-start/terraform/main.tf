# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  nomad_version    = "1.3.0"
  nomad_checksum   = "df1f52054a3aaf6db2a564a1bad8bc80902e71746771fe3db18ed4c85cf2c2b1"

  consul_version   = "1.12.0"
  consul_checksum  = "109e2077236cae4560b2fa3dce7974ef58d6a7093d72494614d875e5c86e3b2c"

  vault_version    = "1.10.3"
  vault_checksum   = "c99aeefd30dbeb406bfbd7c80171242860747b3bf9fa377e7a9ec38531727f31"

  traefik_version  = "v2.6.6"
  traefik_checksum = "cf4afc3f4bff687fccf85cce1cb0f46b40c9f81c2637580eda189abfee0cf55b"

  bindle_version   = "v0.8.0"
  bindle_checksum  = "26f68ab5a03c7e6f0c8b83fb199ca77244c834f25247b9a62312eb7a89dba93c"

  spin_version     = "v0.2.0"
  spin_checksum    = "f5c25a7f754ef46dfc4b2361d6f34d40564768a60d7bc0d183dc26fe1bdcfae0"

  hippo_version    = "v0.10.0"
  hippo_checksum   = "5c82885b179bc392698343a5bdb36954dfdab1442e333fce32ef38f49548bc8e"
}

# -----------------------------------------------------------------------------
# AMI using Canonical's Ubuntu AMD64 offering
# -----------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# -----------------------------------------------------------------------------
# VPC and Networking
# -----------------------------------------------------------------------------

# TODO: (vdice) I honestly can't tell if all this malarkey is any better than just
# launching the instance in the stock vpc (w/ public ip) and associated eip
#
# Here's another guide with even more complication:
# https://dev.to/rhuaridh/terraform-place-your-ec2-instance-in-a-private-subnet-51eh
#
# I suppose there may be benefits of creating all of these as standalong resources
# rather than using the defaults in a given account, but if the overhead of grok-ing
# this is high -- and there's no real discernible security improvements -- then
# perhaps we should remove.

resource "aws_vpc" "default" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = "${var.instance_name}-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.default.id
}

resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = var.subnet_cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.instance_name}-subnet"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  dynamic "route" {
    for_each = var.allowed_inbound_cidr_blocks
    content {
      cidr_block = route.value
      gateway_id = aws_internet_gateway.gw.id
    }
  }

  tags = {
    Name = "${var.instance_name}-vpc-route-table"
  }
}

resource "aws_route_table_association" "public"{
  subnet_id = "${aws_subnet.default.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_network_interface" "default" {
  subnet_id   = aws_subnet.default.id
  private_ips = [var.private_ip_address]
  security_groups = [aws_security_group.ec2.id]

  tags = {
    Name = "${var.instance_name}-network-interface"
  }
}

# -----------------------------------------------------------------------------
# Elastic IP to persist through instance restarts and serve as a known value
# for filling out DNS via chosen host, eg 44.194.137.14.sslip.io
# -----------------------------------------------------------------------------

resource "aws_eip" "lb" {
  vpc      = true

  tags = {
    Name = "${var.instance_name}-eip"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_eip_association" "lb" {
  instance_id   = aws_instance.ec2.id
  allocation_id = aws_eip.lb.id
  private_ip_address = var.private_ip_address

  depends_on = [
    aws_eip.lb,
    aws_instance.ec2
  ]
}

# -----------------------------------------------------------------------------
# EC2 config
# -----------------------------------------------------------------------------

resource "aws_instance" "ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.ec2_ssh_key_pair.key_name

  network_interface {
    network_interface_id = aws_network_interface.default.id
    device_index         = 0
  }

  provisioner "file" {
    source      = "${path.module}/ec2_assets/"
    destination = "/home/ubuntu"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ec2_ssh_key.private_key_pem
    }
  }

  user_data = templatefile("${path.module}/scripts/user-data.sh",
    {
      dns_zone         = "${aws_eip.lb.public_ip}.${var.dns_host}",
      letsencrypt_env  = var.letsencrypt_env,
      nomad_version    = local.nomad_version,
      nomad_checksum   = local.nomad_checksum,
      consul_version   = local.consul_version,
      consul_checksum  = local.consul_checksum,
      vault_version    = local.vault_version,
      vault_checksum   = local.vault_checksum,
      traefik_version  = local.traefik_version,
      traefik_checksum = local.traefik_checksum,
      bindle_version   = local.bindle_version,
      bindle_checksum  = local.bindle_checksum,
      spin_version     = local.spin_version,
      spin_checksum    = local.spin_checksum,
      hippo_version    = local.hippo_version,
      hippo_checksum   = local.hippo_checksum,
    }
  )

  tags = {
    Name = var.instance_name
  }
}

# -----------------------------------------------------------------------------
# Security group/rules to specify allowed inbound/outbound addresses/ports
# -----------------------------------------------------------------------------

# TODO: Add ports for:
#       - Hashistack APIs/dashboards?

resource "aws_security_group" "ec2" {
  name_prefix = var.instance_name
  vpc_id      = aws_vpc.default.id

  tags = {
    Name = "${var.instance_name}-security-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_ssh_inbound" {
  count       = length(var.allowed_ssh_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.allowed_ssh_cidr_blocks

  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "allow_traefik_app_http_inbound" {
  count       = length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "allow_traefik_app_https_inbound" {
  count       = length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = var.allow_outbound_cidr_blocks

  security_group_id = aws_security_group.ec2.id
}

# -----------------------------------------------------------------------------
# SSH keypair
# -----------------------------------------------------------------------------

resource "tls_private_key" "ec2_ssh_key" {
  algorithm   = "RSA"
  rsa_bits    = "4096"
}

resource "aws_key_pair" "ec2_ssh_key_pair" {
  key_name   = "${var.instance_name}_ssh_key_pair"
  public_key = tls_private_key.ec2_ssh_key.public_key_openssh
}

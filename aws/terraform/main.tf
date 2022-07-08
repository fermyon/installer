# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  dependencies = yamldecode(file("../../share/terraform/dependencies.yaml"))

  common_tags = {
    FermyonInstallation = var.instance_name
  }
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
# Default VPC
# -----------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

# -----------------------------------------------------------------------------
# Elastic IP to persist through instance restarts and serve as a known value
# for filling out DNS via chosen host, eg 44.194.137.14
# -----------------------------------------------------------------------------

resource "aws_eip" "lb" {
  vpc = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.instance_name}-eip"
    }
  )
}

resource "aws_eip_association" "lb" {
  instance_id   = aws_instance.ec2.id
  allocation_id = aws_eip.lb.id

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

  # Add config files, scripts, Nomad jobs to host
  provisioner "file" {
    source      = "../../share/terraform/vm_assets/"
    destination = "/home/ubuntu"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ec2_ssh_key.private_key_pem
    }
  }

  user_data = templatefile("../../share/terraform/scripts/startup.sh",
    {
      home_path          = "/home/ubuntu"
      dns_zone           = var.dns_host == "sslip.io" ? "${aws_eip.lb.public_ip}.${var.dns_host}" : var.dns_host,
      enable_letsencrypt = var.enable_letsencrypt,

      nomad_version  = local.dependencies.nomad.version,
      nomad_checksum = local.dependencies.nomad.checksum,

      consul_version  = local.dependencies.consul.version,
      consul_checksum = local.dependencies.consul.checksum,

      vault_version  = local.dependencies.vault.version,
      vault_checksum = local.dependencies.vault.checksum,

      traefik_version  = local.dependencies.traefik.version,
      traefik_checksum = local.dependencies.traefik.checksum,

      bindle_version  = local.dependencies.bindle.version,
      bindle_checksum = local.dependencies.bindle.checksum,

      spin_version  = local.dependencies.spin.version,
      spin_checksum = local.dependencies.spin.checksum,

      hippo_version           = local.dependencies.hippo.version,
      hippo_checksum          = local.dependencies.hippo.checksum,
      hippo_registration_mode = var.hippo_registration_mode
      hippo_admin_username    = var.hippo_admin_username
      # TODO: ideally, Hippo will support ingestion of the admin password via
      # its hash (eg bcrypt, which Traefik and Bindle both support) - then we can remove
      # the need to pass the raw value downstream to the scripts, Nomad job, ecc.
      hippo_admin_password = random_password.hippo_admin_password.result,
    }
  )

  vpc_security_group_ids = [aws_security_group.ec2.id]

  tags = merge(
    local.common_tags,
    {
      Name = var.instance_name
    }
  )
}

# -----------------------------------------------------------------------------
# Security group/rules to specify allowed inbound/outbound addresses/ports
# -----------------------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name_prefix = var.instance_name
  vpc_id      = data.aws_vpc.default.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.instance_name}-security-group"
    }
  )

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
  count       = !var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "allow_traefik_app_https_inbound" {
  count       = var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "allow_nomad_api_inbound" {
  count       = var.allow_inbound_http_nomad && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 4646
  to_port     = 4646
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "allow_consul_api_inbound" {
  count       = var.allow_inbound_http_consul && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 8500
  to_port     = 8500
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
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "aws_key_pair" "ec2_ssh_key_pair" {
  key_name   = "${var.instance_name}_ssh_key_pair"
  public_key = tls_private_key.ec2_ssh_key.public_key_openssh

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Hippo admin password
# -----------------------------------------------------------------------------

resource "random_password" "hippo_admin_password" {
  length           = 22
  special          = true
  override_special = "!#%&*-_=+<>:?"
}

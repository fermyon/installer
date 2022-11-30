# -----------------------------------------------------------------------------
# Hashistack + Fermyon Platform versions
# -----------------------------------------------------------------------------

locals {
  dependencies = yamldecode(file("../../../share/terraform/dependencies.yaml"))

  availability_zone = "${data.aws_region.current.name}b"

  common_tags = {
    FermyonInstallation = "${var.resource_name_prefix}-resources"
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
# Region
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

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

resource "aws_eip" "server_eip" {
  vpc = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.resource_name_prefix}-eip"
    }
  )
}

resource "aws_eip_association" "lb" {
  instance_id   = aws_instance.first_server.id
  allocation_id = aws_eip.server_eip.id

  depends_on = [
    aws_eip.server_eip,
    aws_instance.first_server
  ]
}

# -----------------------------------------------------------------------------
# IAM role for consul cloud auto-join
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "server_instance_profile" {
  name = "${var.resource_name_prefix}-server"
  role = aws_iam_role.server_role.name
}

resource "aws_iam_role_policy" "server_role_policy" {
  name   = "${var.resource_name_prefix}-server"
  role   = aws_iam_role.server_role.name
  policy = <<EOF
{
    "Statement": [
        {
            "Sid": "consulautojoin",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:AttachVolume",
                "ec2:DetachVolume"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "server_role" {
  name               = "${var.resource_name_prefix}-server"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# -----------------------------------------------------------------------------
# Script files
# -----------------------------------------------------------------------------

data "template_file" "server_userdata" {
  template = file("./scripts/startup.sh.tpl")
  vars = {
    home_path          = "/home/ubuntu"
    region             = data.aws_region.current.name
    public_ip          = aws_eip.server_eip.public_ip
    dns_zone           = var.dns_host == "sslip.io" ? "${aws_eip.server_eip.public_ip}.${var.dns_host}" : var.dns_host,
    enable_letsencrypt = var.enable_letsencrypt,

    consul_install_snippet = data.template_file.consul_install_snippet.rendered
    nomad_install_snippet  = data.template_file.nomad_install_snippet.rendered

    traefik_version  = local.dependencies.traefik.version,
    traefik_checksum = local.dependencies.traefik.checksum,

    bindle_version   = local.dependencies.bindle.version,
    bindle_checksum  = local.dependencies.bindle.checksum,
    bindle_volume_id = aws_ebs_volume.bindle.id

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
}

data "template_file" "consul_install_snippet" {
  template = file("./scripts/install_consul.sh.tpl")
  vars = {
    consul_version  = local.dependencies.consul.version
    consul_checksum = local.dependencies.consul.checksum
    consul_count    = var.server_count
  }
}

data "template_file" "nomad_install_snippet" {
  template = file("./scripts/install_nomad.sh.tpl")
  vars = {
    home_path                  = "/home/ubuntu"
    nomad_version              = local.dependencies.nomad.version
    nomad_checksum             = local.dependencies.nomad.checksum
    nomad_count                = var.server_count
    aws_ebs_volume_postgres_id = aws_ebs_volume.postgres.id
    aws_ebs_volume_bindle_id   = aws_ebs_volume.bindle.id
  }
}

# -----------------------------------------------------------------------------
# EC2 config
# -----------------------------------------------------------------------------

resource "aws_instance" "first_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  availability_zone      = local.availability_zone
  user_data              = base64encode(data.template_file.server_userdata.rendered)
  iam_instance_profile   = aws_iam_instance_profile.server_instance_profile.name
  key_name               = aws_key_pair.ec2_ssh_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.server_sg.id]

  # Add config files, scripts, Nomad jobs to host
  provisioner "file" {
    source      = "./vm_assets/"
    destination = "/home/ubuntu"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ec2_ssh_key.private_key_pem
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name          = "${var.resource_name_prefix}-server",
      ConsulRole    = "consul-server"
      IsFirstServer = "true"
    }
  )
}

resource "aws_instance" "other_servers" {
  count                  = var.server_count - 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  availability_zone      = local.availability_zone
  user_data              = base64encode(data.template_file.server_userdata.rendered)
  iam_instance_profile   = aws_iam_instance_profile.server_instance_profile.name
  key_name               = aws_key_pair.ec2_ssh_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.server_sg.id]

  # Add config files, scripts, Nomad jobs to host
  provisioner "file" {
    source      = "./vm_assets/"
    destination = "/home/ubuntu"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ec2_ssh_key.private_key_pem
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name          = "${var.resource_name_prefix}-server",
      ConsulRole    = "consul-server"
      IsFirstServer = "false"
    }
  )
}

# -----------------------------------------------------------------------------
# EBS config
# -----------------------------------------------------------------------------

resource "aws_ebs_volume" "postgres" {
  availability_zone = local.availability_zone
  size              = var.postgres_disk_size

  tags = merge(
    local.common_tags,
    {
      Name = "${var.resource_name_prefix}-postgres-volume"
    }
  )
}

resource "aws_ebs_volume" "bindle" {
  availability_zone = local.availability_zone
  size              = var.bindle_disk_size

  tags = merge(
    local.common_tags,
    {
      Name = "${var.resource_name_prefix}-bindle-volume"
    }
  )
}

# -----------------------------------------------------------------------------
# Security group/rules to specify allowed inbound/outbound addresses/ports
# -----------------------------------------------------------------------------

resource "aws_security_group" "server_sg" {
  name_prefix = "${var.resource_name_prefix}-server-sg"
  vpc_id      = data.aws_vpc.default.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.resource_name_prefix}-server-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_consul_http_internal" {
  description = "Consul HTTP from the same security group"
  type        = "ingress"
  protocol    = "TCP"
  from_port   = 8500
  to_port     = 8500
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_dns_tcp_internal" {
  description = "DNS from the same security group"
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 8600
  to_port     = 8600
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_dns_udp_internal" {
  description = "DNS from the same security group"
  type        = "ingress"
  protocol    = "udp"
  from_port   = 8600
  to_port     = 8600
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_consul_rpc_internal" {
  description = "Consul RPC from the same security group"
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 8300
  to_port     = 8300
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_consul_lan_serf_tcp_internal" {
  description = "Consul LAN Serf from the same security group"
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 8301
  to_port     = 8301
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_consul_lan_serf_udp_internal" {
  description = "Consul LAN Serf from the same security group"
  type        = "ingress"
  protocol    = "udp"
  from_port   = 8301
  to_port     = 8301
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_nomad_http_internal" {
  description = "Nomad HTTP from the same security group"
  type        = "ingress"
  protocol    = "TCP"
  from_port   = 4646
  to_port     = 4646
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_nomad_rpc_internal" {
  description = "Nomad RPC from the same security group"
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 4647
  to_port     = 4647
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_nomad_lan_serf_tcp_internal" {
  description = "Nomad LAN Serf from the same security group"
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 4648
  to_port     = 4648
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_nomad_lan_serf_udp_internal" {
  description = "Nomad LAN Serf from the same security group"
  type        = "ingress"
  protocol    = "udp"
  from_port   = 4648
  to_port     = 4648
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_nomad_dynamic_ports_internal" {
  # Nomad dynamic port (default 20000-32000)
  # ref: https://www.nomadproject.io/docs/job-specification/network#dynamic-ports
  description = "Nomad dynamic ports"
  type        = "ingress"
  protocol    = "TCP"
  from_port   = 20000
  to_port     = 32000
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_postgresql_internal" {
  description = "PostgreSQL from the same security group"
  type        = "ingress"
  protocol    = "TCP"
  from_port   = 5432
  to_port     = 5432
  self        = true

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_egress" {
  type        = "egress"
  protocol    = -1
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_hippo_inbound" {
  description = "Hippo port"
  type        = "ingress"
  protocol    = "TCP"
  from_port   = 5000
  to_port     = 5000
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_server_ssh_inbound" {
  count       = length(var.allowed_ssh_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.allowed_ssh_cidr_blocks

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_traefik_app_http_inbound" {
  count       = !var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_traefik_app_https_inbound" {
  count       = var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_traefik_dashboard_inbound" {
  count       = !var.enable_letsencrypt && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 8081
  to_port     = 8081
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_nomad_api_inbound" {
  count       = var.allow_inbound_http_nomad && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 4646
  to_port     = 4646
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.server_sg.id
}

resource "aws_security_group_rule" "allow_consul_api_inbound" {
  count       = var.allow_inbound_http_consul && length(var.allowed_inbound_cidr_blocks) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 8500
  to_port     = 8500
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = aws_security_group.server_sg.id
}

# -----------------------------------------------------------------------------
# SSH keypair
# -----------------------------------------------------------------------------

resource "tls_private_key" "ec2_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "aws_key_pair" "ec2_ssh_key_pair" {
  key_name   = "${var.resource_name_prefix}_ssh_key_pair"
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

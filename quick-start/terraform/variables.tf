variable "instance_name" {
  description = "The name of the EC2 instance; should be unique if multiple are launched in the same region"
  type        = string
  default     = "fermyon-hashistack"
}

variable "instance_type" {
  description = "The type of EC2 Instance to run for each node in the cluster (e.g. t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "letsencrypt_env" {
  description = "The Let's Encrypt URL to request certs from. Options are 'staging' or 'prod'."
  type        = string
  default     = "staging"
}

variable "dns_host" {
  description = "The DNS host to use for construction of the root domain for Fermyon Platform services and apps"
  type        = string
  default     = "sslip.io"
}

variable "allowed_ssh_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the EC2 Instance will allow SSH connections"
  type        = list(string)
  # To restrict to a single IP, e.g. 75.75.75.75, use 75.75.75.75/32
  default     = ["0.0.0.0/0"]
}

variable "allowed_inbound_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the EC2 Instance will allow connections"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_outbound_cidr_blocks" {
  description = "Allow outbound traffic to these CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpc_cidr_block" {
  description = "CIDR block for the dedicated VPC for this example"
  type        = string
  default     = "10.0.0.0/24"
}

variable "subnet_cidr_block" {
  description = "CIDR block for the subnet in the VPC for the EC2 instance"
  type        = string
  default     = "10.0.0.0/28"
}

variable "private_ip_address" {
  description = "The private IP address for the EC2 instance"
  type        = string
  # Note: AWS reserves the first 4 and last IP address in each subnet CIDR block
  # https://stackoverflow.com/questions/64212709/how-do-i-assign-an-ec2-instance-to-a-fixed-ip-address-within-a-subnet
  default     = "10.0.0.4"
}
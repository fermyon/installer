variable "instance_name" {
  description = "The name of the EC2 instance"
  type        = string
  default     = "fermyon-hashistack"
}

variable "instance_type" {
  description = "The type of EC2 Instances to run for each node in the cluster (e.g. t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "allowed_ssh_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the EC2 Instances will allow SSH connections"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_inbound_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the EC2 Instances will allow connections"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_outbound_cidr_blocks" {
  description = "Allow outbound traffic to these CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]
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
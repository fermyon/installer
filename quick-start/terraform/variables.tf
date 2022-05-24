variable "instance_name" {
  description = "The name of the EC2 instance; should be unique if multiple are launched in the same region"
  type        = string
  default     = "fermyon-hashistack"
}

variable "instance_type" {
  description = "The type of EC2 Instance to run for each node in the cluster (Default: t2.small)"
  type        = string
  default     = "t2.small"
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

variable "allow_inbound_http_nomad" {
  description = "Allow inbound connections to the unsecured Nomad API http port"
  type        = bool
  default     = false
}

variable "allow_inbound_http_consul" {
  description = "Allow inbound connections to the unsecured Consul API http port"
  type        = bool
  default     = false
}

variable "basic_auth_username" {
  description = "Basic auth username for authenticating with Bindle and Hippo"
  type        = string
  default     = "admin"
}

variable "region" {
  description = "DigitalOcean region (Default: nyc1)"
  type        = string
  default     = "nyc1"
}

variable "vpc_name" {
  description = "The name of the VPC; should be unique if multiple are launched in the same project (Default: fermyon-vpc)"
  type        = string
  default     = "fermyon-vpc"
}

variable "droplet_name" {
  description = "The name of the Droplet instance; should be unique if multiple are launched in the same region"
  type        = string
  default     = "fermyon"
}

variable "droplet_size" {
  description = "The size of Droplet to run for each node in the cluster (Default: s-2vcpu-2gb)"
  type        = string
  default     = "s-2vcpu-2gb"
}

variable "enable_letsencrypt" {
  description = "Enable cert provisioning via Let's Encrypt"
  type        = bool
  default     = false
}

variable "dns_host" {
  description = "The DNS host to use for construction of the root domain for Fermyon Platform services and apps"
  type        = string
  default     = "sslip.io"
}

variable "allowed_ssh_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the DO Instance will allow SSH connections"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_inbound_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the DO Instance will allow connections"
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

variable "hippo_admin_username" {
  description = "Admin username for Hippo when running in AdministratorOnly mode"
  type        = string
  default     = "admin"
}

variable "hippo_registration_mode" {
  description = "The registration mode for Hippo. Options are 'Open', 'Closed' and 'AdministratorOnly'. (Default: AdministratorOnly)"
  type        = string
  default     = "AdministratorOnly"

  validation {
    condition     = var.hippo_registration_mode == "Open" || var.hippo_registration_mode == "Closed" || var.hippo_registration_mode == "AdministratorOnly"
    error_message = "The Hippo registration mode must be 'Open', 'Closed' or 'AdministratorOnly'."
  }
}

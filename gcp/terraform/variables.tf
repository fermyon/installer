variable "project_id" {
  description = "The project id in GCP"
  type        = string
}

variable "region" {
  description = "GCP region (Default: us-central1)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone (Default: us-central1-a)"
  type        = string
  default     = "us-central1-a"
}

variable "vpc_name" {
  description = "The name of the VPC; should be unique if multiple are launched in the same project (Default: fermyon-vpc)"
  type        = string
  default     = "fermyon-vpc"
}

variable "instance_name" {
  description = "The name of the VM instance; should be unique if multiple are launched in the same region (Default: fermyon)"
  type        = string
  default     = "fermyon"
}

variable "instance_type" {
  description = "The type of VM Instance to run for each node in the cluster (Default: g1-small)"
  type        = string
  default     = "e1-small"
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
  description = "A list of CIDR-formatted IP address ranges from which the VM Instance will allow SSH connections"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_inbound_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the VM Instance will allow connections"
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

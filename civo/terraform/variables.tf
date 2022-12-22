variable "region" {
  description = "Civo region (Default: nyc1)"
  type        = string
  default     = "NYC1"
}

variable "network_name" {
  description = "The name of the network; should be unique if multiple are launched in the same project (Default: fermyon)"
  type        = string
  default     = "fermyon"
}

variable "instance_name" {
  description = "The name of the Civo instance; should be unique if multiple are launched in the same region"
  type        = string
  default     = "fermyon"
}

variable "instance_size" {
  description = "The size of Droplet to run for each node in the cluster (Default: g3.large)"
  type        = string
  default     = "g3.large"
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


variable "allowed_inbound_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the Civo Instance will allow connections"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_outbound_cidr_blocks" {
  description = "Allow outbound traffic to these CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]
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

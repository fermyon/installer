variable "project_id" {
  description = "Equinix Metal Project ID"
  type        = string
}

variable "metros" {
  description = "Metro (Default: Dallas: [da])"
  type        = list(string)
  default     = ["da", "am"]
}

variable "server_name" {
  description = "The name of the server. Should be unique if multiple are launched in the same region"
  type        = string
  default     = "fermyon"
}

variable "server_type" {
  description = "The server type to run for each node in the cluster (Default: c3.small.x86)"
  type        = string
  default     = "c3.small.x86"
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

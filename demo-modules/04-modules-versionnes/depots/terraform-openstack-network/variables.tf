variable "name" {
  description = "Nom de base : réseau, sous-réseau et routeur en dérivent"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name))
    error_message = "name : minuscules, chiffres et tirets, 2 à 21 caractères."
  }
}

variable "cidr" {
  description = "CIDR IPv4 du sous-réseau (ex. 10.40.4.0/24)"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.cidr))
    error_message = "cidr doit être un CIDR IPv4 valide."
  }
}

variable "dns_nameservers" {
  description = "DNS annoncés par le DHCP"
  type        = list(string)
  default     = ["8.8.8.8"]
}

variable "external_network_id" {
  description = "ID du réseau externe (passerelle du routeur)"
  type        = string
}

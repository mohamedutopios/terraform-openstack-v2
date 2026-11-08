variable "name" {
  description = "Nom du security group"
  type        = string
}

variable "description" {
  description = "Description du security group"
  type        = string
  default     = "Géré par Terraform"
}

variable "delete_default_rules" {
  description = "Supprimer les règles egress créées par défaut par Neutron"
  type        = bool
  default     = false
}

# v2.0.0 (CASSANT) : remote_ip_prefix n'a plus de valeur par défaut.
# En v1, l'oubli de ce champ ouvrait silencieusement la règle à 0.0.0.0/0.
variable "rules" {
  description = "Règles ingress : protocole, plage de ports, CIDR source (obligatoire)"
  type = list(object({
    protocol         = string
    port_min         = optional(number)
    port_max         = optional(number)
    remote_ip_prefix = string
  }))

  validation {
    condition     = alltrue([for r in var.rules : contains(["tcp", "udp", "icmp"], r.protocol)])
    error_message = "protocol doit valoir tcp, udp ou icmp."
  }

  validation {
    condition     = alltrue([for r in var.rules : can(cidrnetmask(r.remote_ip_prefix))])
    error_message = "remote_ip_prefix doit être un CIDR IPv4 valide (ex. 192.168.57.0/24)."
  }

  # Garde-fou de sécurité porté par le module : il protège TOUS ses
  # consommateurs, au plan, avant même Checkov.
  validation {
    condition = !anytrue([
      for r in var.rules :
      r.protocol == "tcp" && r.remote_ip_prefix == "0.0.0.0/0" &&
      coalesce(r.port_min, 0) <= 22 && coalesce(r.port_max, 65535) >= 22
    ])
    error_message = "SSH (tcp/22) ouvert à 0.0.0.0/0 est interdit : restreindre remote_ip_prefix."
  }
}

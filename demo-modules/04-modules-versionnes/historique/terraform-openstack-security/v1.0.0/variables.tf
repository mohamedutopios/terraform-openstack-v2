variable "name" {
  description = "Nom du security group"
  type        = string
}

variable "description" {
  description = "Description du security group"
  type        = string
  default     = "Géré par Terraform"
}

# remote_ip_prefix vaut 0.0.0.0/0 si on l'omet : pratique... et dangereux.
variable "rules" {
  description = "Règles ingress : protocole, plage de ports, CIDR source"
  type = list(object({
    protocol         = string
    port_min         = optional(number)
    port_max         = optional(number)
    remote_ip_prefix = optional(string, "0.0.0.0/0")
  }))
}

variable "cloud_name" {
  description = "Nom de l'entrée dans clouds.yaml"
  type        = string
}

# Valeur par défaut (et non dans terraform.tfvars, prioritaire sur
# l'environnement) : en CI, TF_VAR_public_key_path la remplace.
variable "public_key_path" {
  description = "Chemin de la clé publique SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "image_name" {
  description = "Image de la VM"
  type        = string
}

variable "flavor_name" {
  description = "Flavor de la VM"
  type        = string
}

variable "external_network_name" {
  description = "Réseau externe existant"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR du sous-réseau privé"
  type        = string
}

variable "dns_nameservers" {
  description = "DNS annoncés par le DHCP"
  type        = list(string)
}

variable "admin_cidr" {
  description = "Réseau autorisé en SSH (celui d'où l'on administre)"
  type        = string
}

variable "vm_count" {
  description = "Nombre de VM (module compute >= 1.1.0)"
  type        = number
  default     = 1
}

variable "environnement" {
  description = "Nom de l'environnement : doit être celui du dossier envs/<nom>"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environnement)
    error_message = "environnement doit valoir dev, staging ou prod."
  }
}

variable "cloud_name" {
  description = "Entrée de clouds.yaml (une par environnement)"
  type        = string
}

# Valeur par défaut et non tfvars : en CI, TF_VAR_public_key_path la remplace
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
  description = "CIDR du sous-réseau privé (distinct par environnement)"
  type        = string
}

variable "dns_nameservers" {
  description = "DNS annoncés par le DHCP"
  type        = list(string)
}

variable "admin_cidr" {
  description = "Réseau autorisé en SSH"
  type        = string
}

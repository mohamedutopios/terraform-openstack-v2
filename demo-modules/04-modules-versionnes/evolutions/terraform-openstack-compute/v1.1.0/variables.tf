variable "name" {
  description = "Nom de base : la VM, le port et la keypair en dérivent"
  type        = string
}

variable "instance_count" {
  description = "Nombre de VM identiques (1 à 5). À 1, les noms sont ceux de la 1.0.0 ; au-delà, suffixe -1, -2..."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 5 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count doit être un entier entre 1 et 5."
  }
}

variable "image_name" {
  description = "Image Glance de la VM"
  type        = string
}

variable "flavor_name" {
  description = "Flavor de la VM"
  type        = string
}

variable "public_key" {
  description = "Contenu de la clé publique SSH (pas le chemin)"
  type        = string
}

variable "network_id" {
  description = "Réseau où brancher la VM"
  type        = string
}

variable "subnet_id" {
  description = "Sous-réseau pour l'IP fixe"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups appliqués au port"
  type        = list(string)
}

variable "create_floating_ip" {
  description = "Associer une IP flottante à chaque VM"
  type        = bool
  default     = false
}

variable "floating_pool" {
  description = "Réseau externe fournissant l'IP flottante (requis si create_floating_ip)"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "cloud-init optionnel"
  type        = string
  default     = null
}

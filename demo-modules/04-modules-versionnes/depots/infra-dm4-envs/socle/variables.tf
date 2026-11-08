variable "cloud_admin" {
  description = "Entrée clouds.yaml du compte administrateur"
  type        = string
  default     = "kolla-aio"
}

variable "auth_url" {
  description = "URL Keystone écrite dans les clouds.yaml générés"
  type        = string
  default     = "http://192.168.56.250:5000"
}

variable "environnements" {
  description = "Quotas de chaque environnement : la prod a plus de capacité, le dev ne peut pas la consommer"
  type = map(object({
    instances = number
    cores     = number
    ram_mo    = number
  }))
  default = {
    dev     = { instances = 2, cores = 2, ram_mo = 1024 }
    staging = { instances = 2, cores = 2, ram_mo = 1024 }
    prod    = { instances = 4, cores = 4, ram_mo = 2048 }
  }
}

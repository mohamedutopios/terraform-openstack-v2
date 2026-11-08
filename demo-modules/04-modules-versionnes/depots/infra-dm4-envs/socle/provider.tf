# Le socle est appliqué UNE fois, par un administrateur, avec le compte
# admin du lab. Il n'est pas joué par la CI des environnements.
provider "openstack" {
  cloud = var.cloud_admin
}

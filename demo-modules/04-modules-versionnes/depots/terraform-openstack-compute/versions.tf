# Un module déclare la version MINIMALE dont il a besoin (>=) ;
# c'est le root (l'infra) qui épingle précisément (~>) et verrouille.
terraform {
  required_version = ">= 1.5"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 2.1"
    }
  }
}

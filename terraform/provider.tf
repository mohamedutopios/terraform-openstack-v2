terraform {
  required_version = ">= 1.5"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.1"
    }
  }
}

# Le fichier clouds.yaml est généré automatiquement dans ce dossier
# par le provisionnement Vagrant (scripts/02-deploy-kolla.sh).
provider "openstack" {
  cloud = "kolla-aio"
}

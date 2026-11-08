# Le ROOT épingle le provider (~>) ; le .terraform.lock.hcl commité fige
# la version exacte et ses empreintes.
terraform {
  required_version = ">= 1.5"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.1"
    }
  }
}

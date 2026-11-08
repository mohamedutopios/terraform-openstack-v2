# Tests unitaires : provider SIMULÉ (mock_provider, Terraform >= 1.7),
# aucun appel à OpenStack. Lancés par le job "terraform-test".
mock_provider "openstack" {}

variables {
  name                = "test"
  cidr                = "10.10.0.0/24"
  external_network_id = "ext-id"
}

run "nommage_derive_du_nom_de_base" {
  command = plan

  assert {
    condition     = openstack_networking_network_v2.this.name == "test-net"
    error_message = "Le réseau doit s'appeler <name>-net."
  }

  assert {
    condition     = openstack_networking_subnet_v2.this.cidr == "10.10.0.0/24"
    error_message = "Le sous-réseau doit reprendre var.cidr."
  }
}

run "refuse_un_cidr_invalide" {
  command = plan

  variables {
    cidr = "10.10.0.0/33"
  }

  expect_failures = [var.cidr]
}

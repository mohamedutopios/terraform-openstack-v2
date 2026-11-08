# Tests unitaires avec provider simulé (aucun appel OpenStack).
mock_provider "openstack" {}

variables {
  name = "test-sg"
  rules = [
    { protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "192.168.57.0/24" },
    { protocol = "icmp", remote_ip_prefix = "0.0.0.0/0" },
  ]
}

run "une_ressource_par_regle" {
  command = plan

  assert {
    condition     = length(openstack_networking_secgroup_rule_v2.this) == 2
    error_message = "Chaque entrée de var.rules doit produire une règle."
  }

  assert {
    condition     = contains(keys(openstack_networking_secgroup_rule_v2.this), "tcp-22-22")
    error_message = "La clé de la règle SSH doit être tcp-22-22."
  }
}

run "refuse_ssh_ouvert_au_monde" {
  command = plan

  variables {
    rules = [{ protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "0.0.0.0/0" }]
  }

  expect_failures = [var.rules]
}

run "refuse_un_cidr_invalide" {
  command = plan

  variables {
    rules = [{ protocol = "icmp", remote_ip_prefix = "partout" }]
  }

  expect_failures = [var.rules]
}

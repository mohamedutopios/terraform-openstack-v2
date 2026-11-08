# Tests unitaires avec provider simulé : logique de count et de nommage,
# sans créer de VM.
mock_provider "openstack" {}

variables {
  name               = "test-vm"
  image_name         = "cirros"
  flavor_name        = "m1.tiny"
  public_key         = "ssh-ed25519 AAAA test"
  network_id         = "net-id"
  subnet_id          = "subnet-id"
  security_group_ids = ["sg-id"]
}

run "sans_ip_flottante_par_defaut" {
  command = plan

  assert {
    condition     = length(openstack_networking_floatingip_v2.this) == 0
    error_message = "Aucune IP flottante ne doit être créée par défaut."
  }
}

run "avec_ip_flottante" {
  command = plan

  variables {
    create_floating_ip = true
    floating_pool      = "public"
  }

  assert {
    condition     = length(openstack_networking_floatingip_v2.this) == 1
    error_message = "create_floating_ip = true doit créer une IP flottante."
  }

  assert {
    condition     = openstack_compute_keypair_v2.this.name == "test-vm-key"
    error_message = "La keypair doit s'appeler <name>-key."
  }
}

# 1.1.0 : la valeur par défaut garde le comportement et les noms de la 1.0.0
run "une_vm_garde_le_nom_de_la_1_0_0" {
  command = plan

  assert {
    condition     = length(openstack_compute_instance_v2.this) == 1 && openstack_compute_instance_v2.this[0].name == "test-vm"
    error_message = "Avec instance_count = 1, la VM doit garder le nom <name>."
  }
}

run "plusieurs_vm" {
  command = plan

  variables {
    instance_count     = 3
    create_floating_ip = true
    floating_pool      = "public"
  }

  assert {
    condition     = [for vm in openstack_compute_instance_v2.this : vm.name] == ["test-vm-1", "test-vm-2", "test-vm-3"]
    error_message = "Les VM doivent s'appeler <name>-1, <name>-2, <name>-3."
  }

  assert {
    condition     = length(openstack_networking_port_v2.this) == 3 && length(openstack_networking_floatingip_v2.this) == 3
    error_message = "Chaque VM doit avoir son port et son IP flottante."
  }

  assert {
    condition     = length(openstack_compute_keypair_v2.this.name) > 0
    error_message = "La keypair reste unique et partagée."
  }
}

run "refuse_trop_de_vm" {
  command = plan

  variables {
    instance_count = 6
  }

  expect_failures = [var.instance_count]
}

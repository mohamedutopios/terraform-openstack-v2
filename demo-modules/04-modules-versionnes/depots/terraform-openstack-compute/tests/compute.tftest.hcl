# Tests unitaires avec provider simulé : on vérifie la logique count
# de l'IP flottante sans créer de VM.
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

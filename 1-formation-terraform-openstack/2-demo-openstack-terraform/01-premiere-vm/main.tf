# Démo 1 — Première VM (version SANS port explicite)
# Nova crée le port automatiquement ; les security groups sont posés sur
# l'instance (par nom) et l'IP flottante est associée via l'API compute.
# Version plus courte, mais moins de contrôle qu'avec un port géré
# (choix du sous-réseau, IP fixe, SG par ID) — voir demo-modules/ pour
# la version avec port explicite.

resource "openstack_compute_keypair_v2" "demo" {
  name       = "demo1-key"
  public_key = file(pathexpand(var.public_key_path))
}

resource "openstack_compute_instance_v2" "vm" {
  name            = "demo1-vm"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.demo.name
  security_groups = [data.openstack_networking_secgroup_v2.ssh_icmp.name]

  network {
    uuid = data.openstack_networking_network_v2.private.id
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  pool = var.floating_pool
}

# Variante compute de l'association (instance_id au lieu de port_id)
resource "openstack_compute_floatingip_associate_v2" "fip" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  instance_id = openstack_compute_instance_v2.vm.id
}

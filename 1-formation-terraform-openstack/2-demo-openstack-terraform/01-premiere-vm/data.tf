# Ressources existantes référencées en lecture seule.
# (Plus besoin du sous-réseau : sans port explicite, Nova choisit lui-même.)

data "openstack_networking_network_v2" "private" {
  name = var.network_name
}

data "openstack_networking_secgroup_v2" "ssh_icmp" {
  name = var.secgroup_name
}

# ---- Sorties 1.1.0 : une valeur par VM ----

output "instance_ids" {
  description = "IDs des VM, dans l'ordre"
  value       = openstack_compute_instance_v2.this[*].id
}

output "private_ips" {
  description = "IP fixes des VM, dans l'ordre"
  value       = [for p in openstack_networking_port_v2.this : p.all_fixed_ips[0]]
}

output "floating_ips" {
  description = "IP flottantes des VM, dans l'ordre (liste vide si create_floating_ip = false)"
  value       = openstack_networking_floatingip_v2.this[*].address
}

# ---- Sorties 1.0.0 conservées pour la compatibilité ----
# DÉPRÉCIÉES : supprimées en 2.0.0. Elles ne décrivent que la 1re VM.

output "instance_id" {
  description = "DÉPRÉCIÉE (suppression en 2.0.0), utiliser instance_ids : ID de la 1re VM"
  value       = openstack_compute_instance_v2.this[0].id
}

output "private_ip" {
  description = "DÉPRÉCIÉE (suppression en 2.0.0), utiliser private_ips : IP fixe de la 1re VM"
  value       = openstack_networking_port_v2.this[0].all_fixed_ips[0]
}

output "floating_ip" {
  description = "DÉPRÉCIÉE (suppression en 2.0.0), utiliser floating_ips : IP flottante de la 1re VM (null si non demandée)"
  value       = var.create_floating_ip ? openstack_networking_floatingip_v2.this[0].address : null
}

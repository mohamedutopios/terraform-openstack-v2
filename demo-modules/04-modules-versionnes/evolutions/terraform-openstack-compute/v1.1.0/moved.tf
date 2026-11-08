# 1.0.0 -> 1.1.0 : le port et la VM passent sous count. Sans ces blocs,
# Terraform verrait "this" disparaître et "this[0]" apparaître : il
# DÉTRUIRAIT la VM existante pour en recréer une. Avec eux, il renomme
# simplement l'adresse dans l'état : c'est ce qui rend la version MINEURE.
moved {
  from = openstack_networking_port_v2.this
  to   = openstack_networking_port_v2.this[0]
}

moved {
  from = openstack_compute_instance_v2.this
  to   = openstack_compute_instance_v2.this[0]
}

cloud_name            = "kolla-aio"
image_name            = "cirros"
flavor_name           = "m1.tiny"
external_network_name = "public"
subnet_cidr           = "10.40.4.0/24"
dns_nameservers       = ["8.8.8.8"]
# Réseau host-only des IP flottantes : l'hôte y a l'adresse 192.168.57.1
admin_cidr = "192.168.57.0/24"

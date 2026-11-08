# Environnement PROD
# - flavor : m1.small visé ; m1.tiny sur le lab (disque de l'hyperviseur limité)
# - SSH : uniquement depuis le poste d'administration (l'hôte du lab)
environnement         = "prod"
cloud_name            = "dm4-prod"
image_name            = "cirros"
flavor_name           = "m1.tiny"
external_network_name = "public"
subnet_cidr           = "10.60.3.0/24"
dns_nameservers       = ["8.8.8.8"]
admin_cidr            = "192.168.57.1/32"

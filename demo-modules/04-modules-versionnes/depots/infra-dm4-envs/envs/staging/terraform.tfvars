# Environnement STAGING : même gabarit que la prod, pour la recette
environnement         = "staging"
cloud_name            = "dm4-staging"
image_name            = "cirros"
flavor_name           = "m1.tiny"
external_network_name = "public"
subnet_cidr           = "10.60.2.0/24"
dns_nameservers       = ["8.8.8.8"]
admin_cidr            = "192.168.57.0/24"

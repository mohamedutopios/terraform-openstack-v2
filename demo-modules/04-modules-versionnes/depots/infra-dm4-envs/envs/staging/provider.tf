# Une entrée clouds.yaml PAR environnement (dm4-dev, dm4-staging, dm4-prod),
# idéalement un projet OpenStack et un compte par environnement (socle/).
# En CI, OS_CLIENT_CONFIG_FILE est une variable GitLab limitée à
# l'environnement : le job de dev ne reçoit jamais les identifiants de prod.
provider "openstack" {
  cloud = var.cloud_name
}

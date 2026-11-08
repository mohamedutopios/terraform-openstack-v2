# Identifiants : clouds.yaml (jamais commité). En CI, son chemin est donné
# par la variable OS_CLIENT_CONFIG_FILE (variable GitLab de type fichier).
provider "openstack" {
  cloud = var.cloud_name
}

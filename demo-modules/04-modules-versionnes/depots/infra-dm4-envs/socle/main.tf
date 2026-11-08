# Socle : un projet OpenStack, un compte technique et des quotas PAR
# environnement. C'est l'isolation la plus forte : la CI de dev, avec son
# compte, ne voit même pas les ressources de prod.

data "openstack_identity_role_v3" "member" {
  name = "member"
}

resource "openstack_identity_project_v3" "env" {
  for_each = var.environnements

  name        = "dm4-${each.key}"
  description = "Démo modules 4 : environnement ${each.key}"
}

resource "random_password" "ci" {
  for_each = var.environnements

  length  = 24
  special = false
}

resource "openstack_identity_user_v3" "ci" {
  for_each = var.environnements

  name               = "ci-dm4-${each.key}"
  description        = "Compte technique de la CI pour dm4-${each.key}"
  default_project_id = openstack_identity_project_v3.env[each.key].id
  password           = random_password.ci[each.key].result
}

resource "openstack_identity_role_assignment_v3" "ci" {
  for_each = var.environnements

  user_id    = openstack_identity_user_v3.ci[each.key].id
  project_id = openstack_identity_project_v3.env[each.key].id
  role_id    = data.openstack_identity_role_v3.member.id
}

resource "openstack_compute_quotaset_v2" "env" {
  for_each = var.environnements

  project_id = openstack_identity_project_v3.env[each.key].id
  instances  = each.value.instances
  cores      = each.value.cores
  ram        = each.value.ram_mo
  key_pairs  = 10
}

locals {
  cloud = {
    for env, _ in var.environnements : env => {
      auth = {
        auth_url            = var.auth_url
        username            = openstack_identity_user_v3.ci[env].name
        password            = random_password.ci[env].result
        project_name        = openstack_identity_project_v3.env[env].name
        user_domain_name    = "Default"
        project_domain_name = "Default"
      }
      region_name          = "RegionOne"
      identity_api_version = 3
    }
  }
}

# clouds.yaml du poste de travail : les trois entrées dm4-<env>
resource "local_sensitive_file" "clouds" {
  filename        = "${path.module}/clouds.yaml"
  file_permission = "0600"
  content = yamlencode({
    clouds = { for env, c in local.cloud : "dm4-${env}" => c }
  })
}

# Un fichier PAR environnement, à déposer dans la variable GitLab
# OS_CLIENT_CONFIG_FILE limitée à cet environnement
resource "local_sensitive_file" "clouds_env" {
  for_each = var.environnements

  filename        = "${path.module}/clouds-${each.key}.yaml"
  file_permission = "0600"
  content = yamlencode({
    clouds = { "dm4-${each.key}" = local.cloud[each.key] }
  })
}

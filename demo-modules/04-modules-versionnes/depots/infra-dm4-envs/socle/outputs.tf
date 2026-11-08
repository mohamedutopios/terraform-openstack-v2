output "projets" {
  description = "Projet OpenStack de chaque environnement"
  value       = { for env, p in openstack_identity_project_v3.env : env => p.name }
}

output "fichiers_clouds" {
  description = "clouds.yaml généré (poste) et un fichier par environnement (variables GitLab)"
  value       = concat([local_sensitive_file.clouds.filename], [for f in local_sensitive_file.clouds_env : f.filename])
}

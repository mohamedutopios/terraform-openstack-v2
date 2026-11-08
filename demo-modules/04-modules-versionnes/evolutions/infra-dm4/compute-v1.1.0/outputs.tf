# compute 1.1.0 : sorties en liste (private_ip / floating_ip sont dépréciées)

output "ips_privees" {
  description = "IP fixes des VM"
  value       = module.vm.private_ips
}

output "ips_flottantes" {
  description = "IP flottantes des VM"
  value       = module.vm.floating_ips
}

output "ssh" {
  description = "Une commande de connexion par VM"
  value       = [for ip in module.vm.floating_ips : "ssh cirros@${ip}"]
}

output "regles_sg" {
  description = "Règles créées par le module security"
  value       = module.security.rule_keys
}

output "environnement" {
  description = "Environnement de cet état (à vérifier avant tout apply)"
  value       = var.environnement
}

output "ip_flottante" {
  description = "IP flottante de la VM"
  value       = module.vm.floating_ip
}

output "ssh" {
  description = "Commande de connexion"
  value       = "ssh cirros@${module.vm.floating_ip}"
}

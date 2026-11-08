output "ssh" {
  description = "Une commande de connexion par VM"
  value       = [for ip in module.vm.floating_ips : "ssh cirros@${ip}"]
}

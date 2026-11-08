# Exemple : SSH limité au réseau d'administration, ICMP ouvert.
module "security" {
  source = "../.."

  name = "exemple-sg"

  rules = [
    { protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "192.168.57.0/24" },
    { protocol = "icmp", remote_ip_prefix = "0.0.0.0/0" },
  ]
}

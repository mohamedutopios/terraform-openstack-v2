# Exemple : SSH et ICMP (CIDR source par défaut).
module "security" {
  source = "../.."

  name = "exemple-sg"

  rules = [
    { protocol = "tcp", port_min = 22, port_max = 22 },
    { protocol = "icmp" },
  ]
}

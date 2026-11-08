locals {
  # Toutes les ressources sont préfixées par l'environnement : dm4-dev-net,
  # dm4-prod-vm... Les trois environnements peuvent coexister.
  prefix = "dm4-${var.environnement}"
}

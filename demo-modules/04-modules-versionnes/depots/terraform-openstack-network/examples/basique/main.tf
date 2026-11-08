# Exemple minimal : sert de documentation exécutable ET de cible aux
# contrôles du pipeline (validate, tflint, checkov, KICS).
module "network" {
  source = "../.."

  name                = "exemple"
  cidr                = "10.99.0.0/24"
  external_network_id = "00000000-0000-0000-0000-000000000000"
}

# TFLint : le plugin "terraform" est intégré au binaire (pas de --init).
# preset "all" : en plus des règles recommandées, impose la structure
# standard d'un module (main/variables/outputs), des variables typées et
# documentées, des noms en snake_case, pas de déclaration inutilisée.
plugin "terraform" {
  enabled = true
  preset  = "all"
}

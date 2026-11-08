# L'état de CET environnement est stocké par GitLab. Un backend n'accepte
# pas de variables : la configuration est partielle ici, et complétée par
# backend.hcl (adresse, propre à chaque environnement) :
#
#   terraform init -backend-config=backend.hcl
#
# Les identifiants ne sont jamais dans le code : TF_HTTP_USERNAME et
# TF_HTTP_PASSWORD (en CI : gitlab-ci-token / $CI_JOB_TOKEN).
terraform {
  backend "http" {}
}

# État GitLab "dm4-dev" du projet infra-dm4-envs (Operate > Terraform states).
# Le nom de l'état DOIT finir par le nom du dossier : contrôlé par le job
# verifier-backends (un copier-coller depuis prod ne passe pas).
address        = "https://gitlab.com/api/v4/projects/mohamed.aijjou1780%2Finfra-dm4-envs/terraform/state/dm4-dev"
lock_address   = "https://gitlab.com/api/v4/projects/mohamed.aijjou1780%2Finfra-dm4-envs/terraform/state/dm4-dev/lock"
unlock_address = "https://gitlab.com/api/v4/projects/mohamed.aijjou1780%2Finfra-dm4-envs/terraform/state/dm4-dev/lock"
lock_method    = "POST"
unlock_method  = "DELETE"
retry_wait_min = 5

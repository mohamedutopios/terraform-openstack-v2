plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Le root doit aussi documenter ses variables et sorties
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

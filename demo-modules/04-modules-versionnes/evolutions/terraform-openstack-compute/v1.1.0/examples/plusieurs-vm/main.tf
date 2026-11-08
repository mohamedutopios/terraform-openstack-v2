# Exemple 1.1.0 : trois VM identiques avec IP flottante, IDs fictifs.
module "vm" {
  source = "../.."

  name               = "web"
  instance_count     = 3
  image_name         = "cirros"
  flavor_name        = "m1.tiny"
  public_key         = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExempleExempleExempleExempleExempleExemple exemple"
  network_id         = "00000000-0000-0000-0000-000000000001"
  subnet_id          = "00000000-0000-0000-0000-000000000002"
  security_group_ids = ["00000000-0000-0000-0000-000000000003"]

  create_floating_ip = true
  floating_pool      = "public"
}

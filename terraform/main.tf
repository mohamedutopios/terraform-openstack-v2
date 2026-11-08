variable "public_key_path" {
  description = "Clé publique SSH injectée dans la VM"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

data "openstack_networking_network_v2" "private" {
  name = "private"
}

data "openstack_networking_subnet_v2" "private" {
  name = "private-subnet"
}

data "openstack_networking_secgroup_v2" "ssh_icmp" {
  name = "allow-ssh-icmp"
}

resource "openstack_compute_keypair_v2" "lab" {
  name       = "lab-key"
  public_key = file(pathexpand(var.public_key_path))
}

resource "openstack_networking_port_v2" "vm" {
  name               = "vm-demo-port"
  network_id         = data.openstack_networking_network_v2.private.id
  security_group_ids = [data.openstack_networking_secgroup_v2.ssh_icmp.id]

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.private.id
  }
}

resource "openstack_compute_instance_v2" "vm" {
  name        = "vm-demo"
  image_name  = "cirros"
  flavor_name = "m1.tiny"
  key_pair    = openstack_compute_keypair_v2.lab.name

  network {
    port = openstack_networking_port_v2.vm.id
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  pool = "public"
}

resource "openstack_networking_floatingip_associate_v2" "fip" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  port_id     = openstack_networking_port_v2.vm.id
}

output "floating_ip" {
  description = "IP joignable depuis la machine hôte (ping / ssh)"
  value       = openstack_networking_floatingip_v2.fip.address
}

output "ssh" {
  value = "ssh cirros@${openstack_networking_floatingip_v2.fip.address}  (mot de passe : gocubsgo)"
}

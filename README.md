# OpenStack AIO — Kolla-Ansible 2024.1 sur VirtualBox (Vagrant)

Services déployés : **Keystone, Nova, Neutron, Glance, Cinder (LVM), Swift, Horizon, Placement** (+ MariaDB, RabbitMQ, HAProxy/Keepalived, Memcached).

## Prérequis

- Hôte **x86_64** (⚠️ ce kit ne fonctionne pas sur Mac Apple Silicon : VirtualBox ARM ne fait tourner que des guests ARM, et l'AIO x86 n'y est pas exploitable — utiliser un poste Intel/AMD ou un serveur Linux distant).
- VirtualBox ≥ 7.0, Vagrant ≥ 2.3, Terraform ≥ 1.5.
- 16 Go de RAM libres, 8 vCPU, ~120 Go de disque.

## Architecture réseau

| Interface VM | Type VirtualBox | Rôle | Adressage |
|---|---|---|---|
| NIC1 | NAT | Sortie Internet de l'AIO (apt, pip, images Docker) | DHCP VirtualBox |
| NIC2 | Host-only | Management + API OpenStack | VM : `192.168.56.10` — VIP Kolla : `192.168.56.250` |
| NIC3 | Host-only (promisc `allow-all`, sans IP) | Réseau externe Neutron (flat `physnet1`) | Floating IPs `192.168.57.100-200`, gateway = hôte `192.168.57.1` |

- **Terraform depuis l'hôte** → APIs sur `http://192.168.56.250:5000` (VIP, via NIC2).
- **VM Nova accessible depuis l'hôte** → floating IP en `192.168.57.x` (via NIC3) : l'hôte possède `192.168.57.1` sur le réseau host-only, il joint directement les floating IPs.

## Démarrage

```bash
vagrant up        # 45 à 60 min (déploiement Kolla complet)
```

À la fin :
- Horizon : `http://192.168.56.250` — utilisateur `admin`, mot de passe dans `terraform/clouds.yaml` (généré automatiquement).
- Ressources créées : réseau externe `public`, réseau `private` + routeur, image `cirros`, flavors `m1.tiny`/`m1.small`, secgroup `allow-ssh-icmp`.

## Terraform depuis l'hôte

```bash
cd terraform
terraform init
terraform apply -auto-approve
ping $(terraform output -raw floating_ip)
ssh cirros@$(terraform output -raw floating_ip)   # mot de passe : gocubsgo
```

Le provider lit `clouds.yaml` dans le dossier courant (`cloud = "kolla-aio"`).

## Vérifications utiles (dans la VM)

```bash
vagrant ssh
source /opt/kolla/bin/activate && source /etc/kolla/admin-openrc.sh
openstack service list
openstack compute service list
openstack network agent list
openstack volume service list
swift stat            # via : openstack container list
docker ps --format '{{.Names}}\t{{.Status}}' | sort
```

Test rapide Cinder / Swift :

```bash
openstack volume create --size 1 vol-test && openstack volume list
openstack container create demo
echo "hello" > /tmp/o.txt && openstack object create demo /tmp/o.txt
openstack object list demo
```

## Limites connues

- **Nova en QEMU (émulation)** : pas de KVM fiable dans VirtualBox → VMs lentes, suffisant pour CirrOS et les TP.
- **Pas d'Internet dans les VMs Nova** : la gateway du réseau `public` est l'hôte (`192.168.57.1`), qui ne fait pas de NAT par défaut. L'accès hôte → VM (le besoin du lab) fonctionne. Pour donner Internet aux VMs, activer le forwarding/NAT sur l'hôte (Linux : `sysctl net.ipv4.ip_forward=1` + règle iptables MASQUERADE sur l'interface de sortie).
- Si VirtualBox refuse le réseau `192.168.57.0/24` : vérifier `/etc/vbox/networks.conf` (la plage par défaut `192.168.56.0/21` couvre 56.x à 63.x, donc normalement rien à faire).

## Reprovisionner après échec

```bash
vagrant provision                              # rejoue les 3 scripts (idempotents)
# ou, dans la VM :
sudo -i
source /opt/kolla/bin/activate
kolla-ansible -i /etc/kolla/all-in-one deploy
```

## Destruction

```bash
cd terraform && terraform destroy -auto-approve
vagrant destroy -f
rm -rf disks/
```

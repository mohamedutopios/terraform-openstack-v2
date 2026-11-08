# OpenStack AIO Kolla — Import de l'OVA

VM Ubuntu 22.04 avec OpenStack 2024.1 pré-déployé (Keystone, Nova, Neutron,
Glance, Cinder, Swift, Horizon, Placement).

## Prérequis

- Machine **x86_64**, VirtualBox ≥ 7.0, **16 Go de RAM libres**, 8 vCPU.
- Terraform ≥ 1.5 pour la partie IaC.

## 1. Importer l'OVA

Interface graphique : *Fichier → Importer un appareil virtuel* → cocher
**« Réinitialiser les adresses MAC »**. Ou en CLI :

```bash
VBoxManage import openstack-aio-kolla.ova --vsys 0 --vmname openstack-aio-kolla
```

## 2. Créer les deux réseaux host-only

L'export OVA ne transporte **ni** les réseaux host-only **ni** le mode
promiscuous : il faut les recréer.

```bash
VBoxManage hostonlyif create
VBoxManage hostonlyif create
```

Puis leur affecter les IP côté hôte (adapter les noms : sous Windows
`"VirtualBox Host-Only Ethernet Adapter"` / `"... #2"`, sous Linux/macOS
`vboxnet0` / `vboxnet1`) :

```bash
VBoxManage hostonlyif ipconfig "VirtualBox Host-Only Ethernet Adapter"    --ip 192.168.56.1 --netmask 255.255.255.0
VBoxManage hostonlyif ipconfig "VirtualBox Host-Only Ethernet Adapter #2" --ip 192.168.57.1 --netmask 255.255.255.0
```

## 3. Rattacher les interfaces de la VM

```bash
VBoxManage modifyvm "openstack-aio-kolla" ^
  --nic1 nat ^
  --nic2 hostonly --hostonlyadapter2 "VirtualBox Host-Only Ethernet Adapter" ^
  --nic3 hostonly --hostonlyadapter3 "VirtualBox Host-Only Ethernet Adapter #2" ^
  --nicpromisc3 allow-all
```

(`^` = continuation PowerShell/cmd ; utiliser `\` sous Linux/macOS.)
⚠️ `--nicpromisc3 allow-all` est **obligatoire** : sans lui, les floating IPs
ne répondent pas depuis l'hôte.

## 4. Démarrer et vérifier

```bash
VBoxManage startvm "openstack-aio-kolla" --type headless
```

Attendre ~5 minutes (redémarrage de tous les conteneurs), puis :

- **Horizon** : http://192.168.56.250 — utilisateur `admin`, mot de passe dans
  `clouds.yaml` (fourni avec l'OVA, également présent dans la VM :
  `/home/vagrant/clouds.yaml`).
- **Connexion VM** : `ssh vagrant@192.168.56.10` (mot de passe `vagrant`),
  puis `sudo -i`.

Vérification interne :

```bash
sudo -i
source /opt/kolla/bin/activate && source /etc/kolla/admin-openrc.sh
docker ps --format '{{.Names}}\t{{.Status}}' | sort   # tous "Up / healthy"
openstack service list
```

## 5. Terraform depuis votre machine

Placer `clouds.yaml` à côté des fichiers `.tf` fournis, puis :

```bash
cd terraform
terraform init
terraform apply -auto-approve
ping <floating_ip affichée en output>
ssh cirros@<floating_ip>        # mot de passe : gocubsgo
```

## Réseau — rappel

| Réseau | Rôle | Depuis l'hôte |
|---|---|---|
| 192.168.56.0/24 | APIs OpenStack (VIP 192.168.56.250) | Terraform, Horizon, SSH VM |
| 192.168.57.0/24 | Floating IPs Neutron (pool .100-.200) | ping/SSH des VMs Nova |

Les VMs Nova n'ont pas d'accès Internet par défaut (gateway = votre hôte,
qui ne route pas) — l'accès hôte → VM, lui, fonctionne nativement.

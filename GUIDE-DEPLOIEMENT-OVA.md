# Déployer l'OVA OpenStack AIO — Guide détaillé

VM Ubuntu 22.04 contenant un OpenStack 2024.1 pré-déployé (Keystone, Nova,
Neutron, Glance, Cinder, Swift, Horizon, Placement).

**Objectif final :**
1. Horizon et Terraform fonctionnent **depuis votre machine**.
2. Les VMs créées dans Nova sont **joignables en SSH depuis votre machine**.

---

## 1. Comprendre le réseau AVANT de cliquer

La VM possède **3 cartes réseau**. Chacune a un rôle précis :

```
VOTRE MACHINE (hôte)
│
├─ Carte 1 de la VM ── NAT VirtualBox ──────────► Internet
│                      (sortie Internet de la VM, rien à configurer)
│
├─ 192.168.56.1 ─── Réseau host-only n°1 ─── Carte 2 de la VM (192.168.56.10)
│   (IP de votre       "réseau MANAGEMENT"        │
│    machine sur                                  └─ VIP OpenStack : 192.168.56.250
│    ce réseau)                                      (Horizon + APIs → cible de Terraform)
│
└─ 192.168.57.1 ─── Réseau host-only n°2 ─── Carte 3 de la VM (pas d'IP)
    (IP de votre       "réseau EXTERNE"           │
     machine sur                                  └─ Neutron y branche les
     ce réseau)                                      FLOATING IPs : 192.168.57.100-200
                                                     (vos VMs Nova, joignables depuis l'hôte)
```

**Un réseau host-only, c'est quoi ?** Un switch virtuel privé entre votre
machine et la VM. VirtualBox crée une carte réseau *sur votre machine*
(visible dans `ipconfig`) avec une IP : c'est par cette carte que votre poste
parle à la VM. Il n'y a ni Internet ni DHCP dessus — tout est statique.

**Pourquoi deux réseaux host-only ?**

| Réseau | Votre machine y a l'IP | La VM y a | Sert à |
|---|---|---|---|
| n°1 : `192.168.56.0/24` | `192.168.56.1` | `192.168.56.10` + VIP `.250` | Horizon, APIs, Terraform, SSH vers l'AIO |
| n°2 : `192.168.57.0/24` | `192.168.57.1` | **aucune IP** (Neutron s'en sert brut) | Floating IPs des VMs Nova |

La carte 3 n'a volontairement pas d'IP : OpenStack (Neutron) la branche sur
son bridge `br-ex` et y fait circuler les IP `192.168.57.1xx` des VMs. Pour
que votre machine voie ces IPs, la carte 3 devra être en **mode promiscuité
« Autoriser tout »** (étape 4.3) — c'est LE réglage que tout le monde oublie.

---

## 2. Importer l'OVA (sans la démarrer)

1. Ouvrir VirtualBox.
2. Menu **Fichier → Importer un appareil virtuel…**
3. Cliquer sur l'icône dossier, sélectionner `openstack-aio-kolla.ova` → **Suivant**.
4. Sur l'écran *Paramètres de l'appareil virtuel* :
   - Vérifier **Processeur : 8** et **RAM : 16384 Mo** (double-cliquer sur la
     valeur pour la modifier ; ne jamais descendre sous 12288 Mo).
   - **Politique d'adresse MAC** : choisir
     **« Générer de nouvelles adresses MAC pour toutes les cartes réseau »**.
5. Cliquer **Terminer**. L'import prend plusieurs minutes.

> ⛔ **Ne démarrez pas la VM maintenant.** Les réseaux host-only n'existent
> pas encore sur votre machine : ils ne sont jamais transportés dans une OVA.

---

## 3. Créer les deux réseaux host-only (Gestionnaire de réseau)

### 3.1 Ouvrir le gestionnaire

Menu **Fichier → Outils → Gestionnaire de réseau**
(en anglais : *File → Tools → Network Manager*).

Une fenêtre s'ouvre avec trois onglets : **Réseaux hôte uniquement (Host-only
Networks)**, Réseaux NAT, Réseaux cloud. Rester sur le premier onglet.

### 3.2 Réseau n°1 — management (192.168.56.0/24)

1. Cliquer sur **Créer**. Une ligne apparaît, par exemple
   `VirtualBox Host-Only Ethernet Adapter` (Windows) ou `vboxnet0` (Linux/macOS).
2. Sélectionner cette ligne. En bas, deux sous-onglets : **Adaptateur** et
   **Serveur DHCP**.
3. Sous-onglet **Adaptateur** :
   - Cocher **Configurer l'adaptateur manuellement**.
   - **Adresse IPv4** : `192.168.56.1`
   - **Masque réseau IPv4** : `255.255.255.0`
4. Sous-onglet **Serveur DHCP** :
   - **Décocher « Activer le serveur »** (aucun DHCP : tout est statique).
5. Cliquer **Appliquer**.

### 3.3 Réseau n°2 — externe / floating IPs (192.168.57.0/24)

1. Cliquer à nouveau sur **Créer** → une deuxième ligne apparaît
   (`... Adapter #2` sous Windows, `vboxnet1` sous Linux/macOS).
2. Sous-onglet **Adaptateur** :
   - Cocher **Configurer l'adaptateur manuellement**.
   - **Adresse IPv4** : `192.168.57.1`
   - **Masque réseau IPv4** : `255.255.255.0`
3. Sous-onglet **Serveur DHCP** : **décocher « Activer le serveur »**.
4. Cliquer **Appliquer**.

### 3.4 ✅ Point de contrôle n°1 — vérifier côté machine

Ouvrir un terminal **sur votre machine** :

```powershell
ipconfig          # Windows        (ip a  sous Linux, ifconfig sous macOS)
```

Vous devez voir **deux** cartes « VirtualBox Host-Only Network » :
l'une en `192.168.56.1`, l'autre en `192.168.57.1`.
Tant que ce n'est pas le cas, ne pas aller plus loin — reprendre 3.2/3.3.

> Noter précisément le **nom** de chaque carte tel qu'affiché par VirtualBox
> (colonne *Nom* du Gestionnaire de réseau) : il servira à l'étape 4.

---

## 4. Brancher les 3 cartes de la VM (Configuration → Réseau)

Sélectionner la VM `openstack-aio-kolla` (éteinte) → bouton **Configuration**
(roue dentée) → section **Réseau**. Quatre onglets : Carte 1 à Carte 4.

### 4.1 Carte 1 — NAT (Internet de la VM)

- **Activer la carte réseau** : coché.
- **Mode d'accès réseau** : `NAT`.
- Rien d'autre à toucher.

### 4.2 Carte 2 — réseau management (192.168.56.x)

- **Activer la carte réseau** : coché.
- **Mode d'accès réseau** : `Réseau privé hôte` (*Host-only Adapter*).
- **Nom** : sélectionner dans la liste déroulante le réseau dont l'IP est
  **192.168.56.1** (créé en 3.2 — ex. `VirtualBox Host-Only Ethernet Adapter`).

### 4.3 Carte 3 — réseau externe (floating IPs) + PROMISCUITÉ

- **Activer la carte réseau** : coché.
- **Mode d'accès réseau** : `Réseau privé hôte`.
- **Nom** : sélectionner le réseau dont l'IP est **192.168.57.1**
  (créé en 3.3 — ex. `... Adapter #2`).
- Cliquer sur le petit triangle **Avancé** pour déplier les options :
  - **Mode Promiscuité** : sélectionner **`Autoriser tout` (Allow All)**.

> 🚨 Sans « Autoriser tout », VirtualBox ne délivre à la carte 3 que le trafic
> destiné à sa propre adresse MAC. Or les floating IPs portent les MAC des
> ports Neutron, pas celle de la carte. Résultat : `terraform apply` réussit,
> mais **aucun ping vers 192.168.57.1xx ne répondra jamais**.

### 4.4 Valider

Cliquer **OK** pour fermer la configuration.

### 4.5 ✅ Point de contrôle n°2 — vérifier le câblage

```bash
VBoxManage showvminfo "openstack-aio-kolla" | grep -i "NIC [1-3]"
```

Attendu (les noms d'adaptateurs peuvent différer) :

```
NIC 1: ... Attachment: NAT ...
NIC 2: ... Attachment: Host-only Interface 'VirtualBox Host-Only Ethernet Adapter' ... Promisc Policy: deny
NIC 3: ... Attachment: Host-only Interface 'VirtualBox Host-Only Ethernet Adapter #2' ... Promisc Policy: allow-all
```

Les 3 points à contrôler : NIC 2 sur l'adaptateur **56**, NIC 3 sur
l'adaptateur **57**, et **`Promisc Policy: allow-all` sur la NIC 3**.

*(Équivalent tout-en-CLI si vous préférez éviter l'interface graphique :)*

```powershell
VBoxManage modifyvm "openstack-aio-kolla" ^
  --nic1 nat ^
  --nic2 hostonly --hostonlyadapter2 "VirtualBox Host-Only Ethernet Adapter" ^
  --nic3 hostonly --hostonlyadapter3 "VirtualBox Host-Only Ethernet Adapter #2" ^
  --nicpromisc3 allow-all
```

---

## 5. Démarrer la VM et attendre OpenStack

1. Sélectionner la VM → **Démarrer** (ou flèche → *Démarrage sans affichage* /
   headless, la console n'est pas nécessaire).
2. Attendre **~5 minutes** : les ~40 conteneurs OpenStack redémarrent.

### ✅ Point de contrôle n°3 — la VM répond

Depuis votre machine :

```bash
ping 192.168.56.10      # la VM AIO répond          → carte 2 OK
ping 192.168.56.250     # la VIP OpenStack répond   → keepalived démarré
```

- `.10` muet → problème carte 2 / réseau host-only n°1 : reprendre étapes 3-4.
- `.10` répond mais pas `.250` → attendre 1-2 min de plus (démarrage en cours).

Puis ouvrir **http://192.168.56.250** : la page de connexion Horizon s'affiche.

- Utilisateur : `admin`
- Mot de passe : champ `password` du fichier `clouds.yaml` fourni avec l'OVA.

---

## 6. (Optionnel) Inspecter l'AIO en SSH

```bash
ssh vagrant@192.168.56.10          # mot de passe : vagrant
sudo -i
source /opt/kolla/bin/activate && source /etc/kolla/admin-openrc.sh
docker ps --format '{{.Names}}\t{{.Status}}' | sort    # tous Up / (healthy)
openstack service list                                  # les 8 services
```

---

## 7. Déployer avec Terraform depuis votre machine

1. Récupérer le dossier `terraform/` fourni : `provider.tf`, `main.tf` et
   `clouds.yaml` **doivent être dans le même dossier**.
2. Avoir une clé SSH : si `~/.ssh/id_rsa.pub` n'existe pas, `ssh-keygen -t rsa`
   (Entrée à toutes les questions).
3. Exécuter :

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

Terraform crée une keypair, un port réseau, une VM CirrOS et lui associe une
floating IP. Sortie attendue :

```text
floating_ip = "192.168.57.1xx"
```

### ✅ Point de contrôle n°4 — l'objectif final

```bash
ping 192.168.57.1xx
ssh cirros@192.168.57.1xx          # mot de passe : gocubsgo
```

Vous êtes connecté, depuis votre poste, à une VM créée dans Nova. 🎉

Nettoyage : `terraform destroy -auto-approve`.

---

## 8. Dépannage

| Symptôme | Cause | Correction |
|---|---|---|
| `ping 192.168.56.10` muet | Carte 2 sur le mauvais adaptateur, ou réseau host-only n°1 absent / mauvaise IP | Étapes 3.2 puis 4.2, contrôles n°1 et n°2 |
| `.10` OK mais Horizon/`.250` muets après 10 min | Conteneurs pas tous démarrés | `docker ps` dans la VM (étape 6) ; laisser finir |
| `terraform apply` : timeout / erreur d'authentification | `clouds.yaml` pas dans le dossier courant, ou `.250` injoignable | Contrôle n°3 ; vérifier l'emplacement du fichier |
| **Floating IP muette** (le cas n°1) | **Promiscuité absente sur la carte 3** | Étape 4.3 ; vérifier `Promisc Policy: allow-all` (contrôle n°2), redémarrer la VM |
| Floating IP muette malgré promisc | Carte 3 branchée sur l'adaptateur 56 au lieu du 57 | Contrôle n°2 : NIC 3 = adaptateur `192.168.57.1` |
| Pas d'Internet dans la VM Nova | Normal : la passerelle du réseau `public` est votre machine, qui ne route pas | Sans impact sur le TP |
| Erreur VT-x/AMD-V au démarrage (Windows) | Hyper-V/WSL2 monopolise la virtualisation | `bcdedit /set hypervisorlaunchtype off` + redémarrer le PC |
| VirtualBox refuse de créer le réseau `192.168.57.x` (Linux) | Restriction `/etc/vbox/networks.conf` | Ajouter la ligne `* 192.168.56.0/21` dans ce fichier |

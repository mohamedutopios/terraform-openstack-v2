# Installation de l'OVA OpenStack AIO — pas à pas

Guide d'import de la VM `openstack-aio-kolla` (Ubuntu 22.04 + OpenStack
2024.1 Kolla pré-déployé) sur un poste VirtualBox. Ce guide reflète la
configuration réseau **actuelle** du lab (réseau NAT pour les instances) et
remplace IMPORT-OVA.md pour cette partie.

## 1. Prérequis

- VirtualBox 7.x + Extension Pack
- Machine hôte : 8 threads CPU et 16 Go de RAM à dédier à la VM,
  ~100 Go de disque libre
- Le fichier `.ova`, à télécharger ici :
  **https://drive.google.com/file/d/1SRfLCj8fzLVupnkX1c-wBtGf45756grU/view?usp=sharing**
  (compte Google requis pour les gros fichiers ; bouton « Télécharger quand
  même » si Drive signale qu'il ne peut pas analyser l'antivirus)

## 2. Créer les réseaux VirtualBox (AVANT le premier démarrage)

Ouvrir **Fichier → Outils → Gestionnaire de réseau** :

### 2a. Réseau host-only (management / Horizon)

Onglet **Host-only Networks** → **Créer** :

| Paramètre | Valeur |
|---|---|
| IPv4 de l'hôte | `192.168.56.1` |
| Masque | `255.255.255.0` |
| Serveur DHCP | **désactivé** |

> C'est par ce réseau que votre navigateur atteindra Horizon
> (`192.168.56.250`). Votre PC y possède l'adresse `.1`.

### 2b. Réseau NAT (réseau externe des instances)

Onglet **NAT Networks** → **Créer** :

| Paramètre | Valeur |
|---|---|
| Nom | `OpenStackNAT` |
| Préfixe IPv4 | `192.168.57.0/24` |
| Serveur DHCP | **décoché** (Neutron gère les IP) |
| IPv6 | désactivé |

> La passerelle du réseau NAT prend automatiquement `192.168.57.1` —
> exactement l'adresse que le routeur Neutron de l'OVA attend comme
> passerelle : les instances ont ainsi accès à Internet sans aucune
> modification d'OpenStack.

## 3. Importer l'OVA

**Fichier → Importer une application virtuelle** → sélectionner le `.ova` →
vérifier : 8 CPU, 16384 Mo de RAM → **Importer** (compter quelques minutes).

En ligne de commande, au choix :

```
VBoxManage import openstack-aio-kolla.ova
```

## 4. Vérifier les 3 cartes réseau de la VM importée

Configuration de la VM → **Réseau** :

| Carte | Mode | Réseau | Avancé |
|---|---|---|---|
| Carte 1 | NAT | — | — |
| Carte 2 | Réseau privé hôte (host-only) | l'adaptateur créé en 2a (hôte = 192.168.56.1) | — |
| Carte 3 | Réseau NAT | `OpenStackNAT` | Promiscuité : « Autoriser tout » si le champ est actif |

> L'import peut perdre l'association des cartes : re-sélectionnez-les si
> nécessaire. L'ordre des cartes est important, ne les intervertissez pas.

## 4bis. Redirection de ports sur la carte 1 (NAT) — et POURQUOI il en faut

### Le principe, une fois pour toutes

Un réseau **NAT est à sens unique** : la VM (ou l'instance) peut ouvrir des
connexions **vers** l'extérieur, mais elle est invisible **depuis**
l'extérieur — le routeur NAT masque son adresse, et personne ne peut
initier une connexion vers elle. C'est exactement comme votre box Internet
à la maison : vous naviguez librement, mais personne ne peut se connecter à
votre PC depuis Internet... sauf si vous ouvrez un port sur la box.

La **redirection de ports** est cette ouverture : « tout ce qui arrive sur
le port X de l'hôte → envoie-le vers le port Y de telle machine derrière le
NAT ». Sans elle, aucun accès entrant n'est possible.

Ce lab comporte **deux étages de NAT**, donc deux endroits où rediriger :

| NAT | Qui est derrière ? | Redirection nécessaire pour... |
|---|---|---|
| Carte 1 (NAT simple) | la VM OpenStack elle-même | SSH vers la VM (`vagrant@`) |
| Réseau NAT `OpenStackNAT` (carte 3) | les instances (IP flottantes) | SSH/HTTP vers les instances (§6) |

À l'inverse, la **carte 2 (host-only) n'a besoin d'aucune redirection** :
votre PC est directement présent sur ce réseau (il y est `192.168.56.1`),
il joint donc la VM (`192.168.56.10`) et Horizon (`192.168.56.250`) sans
intermédiaire. C'est pour ça que le SSH par `192.168.56.10` est la voie
recommandée — la redirection de la carte 1 n'est qu'un plan B.

### Configurer la redirection SSH de la carte 1

Configuration de la VM → **Réseau → Carte 1 (NAT) → Avancé →
Redirection de ports** → ajouter :

| Nom | Proto | IP hôte | Port hôte | IP invité | Port invité |
|---|---|---|---|---|---|
| ssh | TCP | 127.0.0.1 | 2222 | *(laisser vide)* | 22 |

> « IP invité » reste vide : sur un NAT simple, VirtualBox ne dessert
> qu'une seule VM, pas besoin de préciser. Selon la façon dont l'OVA a été
> exportée, cette règle peut déjà être présente — vérifiez avant de la
> créer.

Test : `ssh -p 2222 vagrant@127.0.0.1` (mot de passe `vagrant`).

## 5. Premier démarrage

1. Démarrer la VM (headless suffit : clic droit → Démarrer → Démarrage sans
   affichage).
2. **Patienter 5 à 10 minutes** : les ~53 conteneurs OpenStack redémarrent
   et doivent se stabiliser. N'interagissez pas avant.
3. Test : ouvrir **http://192.168.56.250** dans le navigateur de l'hôte →
   la page de connexion Horizon doit s'afficher.
   - Utilisateur : `admin`
   - Mot de passe : voir §5bis ci-dessous pour le récupérer.

## 5bis. Se connecter en SSH à la VM et récupérer le mot de passe admin

L'OVA embarque un compte générique : **utilisateur `vagrant`, mot de passe
`vagrant`** (valable en SSH et sur la console VirtualBox).

Depuis un terminal de l'hôte, via le réseau host-only (le plus simple) :

```
ssh vagrant@192.168.56.10
```

(mot de passe : `vagrant` — alternative si ce chemin ne répond pas :
`ssh -p 2222 vagrant@127.0.0.1`, une redirection NAT `2222 → 22` existe sur
la carte 1 ; en dernier recours, la console VirtualBox de la VM avec les
mêmes identifiants)

Une fois connecté, récupérer le mot de passe admin d'Horizon :

```
sudo grep keystone_admin_password /etc/kolla/passwords.yml
```

Bonus : un fichier **`/home/vagrant/clouds.yaml`** prêt à l'emploi est
embarqué dans la VM (identifiants admin déjà renseignés). Pour l'utiliser
avec Terraform ou le client openstack depuis votre hôte :

```
scp vagrant@192.168.56.10:clouds.yaml .
```

## 6. Joindre les instances depuis l'hôte (redirections de ports)

Deuxième étage de NAT (cf. §4bis) : le réseau `OpenStackNAT` donne Internet
aux instances, mais leurs IP flottantes (`192.168.57.100-200`) sont
derrière le NAT — invisibles depuis l'hôte. Ici, contrairement à la
carte 1, plusieurs machines vivent derrière le même NAT : chaque règle doit
donc préciser **quelle IP flottante** elle vise. Pour chaque accès
souhaité, ajouter une règle dans **Gestionnaire de réseau → OpenStackNAT →
Redirection de ports → onglet IPv4** :

| Nom | Proto | IP hôte | Port hôte | IP invité | Port invité |
|---|---|---|---|---|---|
| ssh-vm1 | TCP | 127.0.0.1 | 2222 | (IP flottante de la VM) | 22 |
| web-vm1 | TCP | 127.0.0.1 | 8080 | (IP flottante de la VM) | 80 |

Puis cliquer **Appliquer**. Accès : `ssh -i cle.pem -p 2222 cirros@127.0.0.1`
ou `http://127.0.0.1:8080`.

Pièges vérifiés en conditions réelles :
- La règle doit être dans l'onglet **IPv4** (pas IPv6) et **appliquée**.
- Une règle par VM/port ; si vous recréez une VM, son IP flottante change →
  mettre la règle à jour.
- Le `ping` des IP flottantes depuis l'hôte ne fonctionne pas (le NAT ne
  redirige que TCP/UDP) — c'est normal.
- Si vous recréez une VM derrière un port déjà utilisé :
  `ssh-keygen -R "[127.0.0.1]:2222"` pour purger l'ancienne empreinte.

## 7. Vérifications finales (dans Horizon)

1. **Projet → Compute → Instances** : lancer une VM de test (image `cirros`,
   flavor `m1.tiny`, réseau `private`, security group `allow-ssh-icmp`).
2. Lui associer une IP flottante, créer la redirection de ports (cf. §6),
   tester le SSH (`cirros` / mot de passe `gocubsgo`).
3. Dans la VM de test : `ping 8.8.8.8` → doit répondre (Internet via le
   réseau NAT).

## 8. À savoir pour l'exploitation

- **Pas de KVM** : les instances tournent en émulation QEMU. CirrOS boote en
  ~1 min ; une image Ubuntu met 10 à 25 min (astuce : masquer snapd via
  cloud-init `bootcmd: [systemctl mask --now snapd.service snapd.seeded.service snapd.socket]`).
- **Toujours `sudo apt-get update` avant d'installer** dans une instance
  (les index embarqués dans les images cloud sont périmés → erreurs 404).
- **Capacité de l'hyperviseur** : 8 vCPU, 16 Go RAM, **30 Go de disque pour
  l'ensemble des instances** → préférer des flavors ≤ 10 Go de disque.
- **Après un arrêt/redémarrage de la VM OpenStack** : ré-attendre la
  stabilisation des conteneurs (5-10 min) avant toute opération.
- **Security groups** : ils sont PAR PROJET. Dans un nouveau projet, le
  groupe `default` bloque tout en entrée — ajouter ICMP/SSH ou créer un
  groupe dédié avant de tester le ping.

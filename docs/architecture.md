# 🗺️ Architecture

> TP réalisé en école (formation AIS, GRETA). Entreprise fictive : **Menuiserie Valloire** (20 personnes). Laboratoire virtuel sous VMware Workstation.

## Machines

| Machine | Système | IP | Ressources | Rôles |
|---|---|---|---|---|
| **SRVGLPI01** | Debian 13 | 192.168.60.20 (fixe) | 2 Go RAM, 2 vCPU, 2 × 20 Go (RAID 1) + 20 Go (sauvegarde) | Apache, MariaDB, PHP, GLPI 12, agent GLPI |
| **SRV-AD** | Windows Server 2025 | 192.168.60.250 (fixe) | 8 Go RAM, 2 vCPU, 30 Go | AD DS, DNS (zone directe + inversée), agent GLPI |
| Poste d'administration | Windows | NAT | — | SSH (clé), navigateur, PowerShell |

## Réseau

- Réseau NAT `192.168.60.0/24`, passerelle `192.168.60.2`, DHCP de la plateforme de `.128` à `.254`.
- Serveurs en IP fixe **hors de la plage DHCP**.
- Domaine AD : `stephanemetche.local`.

## Flux autorisés

| Source | Destination | Port | Usage |
|---|---|---|---|
| Poste admin | SRVGLPI01 | TCP 2222 | SSH (clé uniquement) |
| Poste admin / utilisateurs | SRVGLPI01 | TCP 80 | Interface GLPI |
| SRVGLPI01 | SRV-AD | TCP 389 | LDAP (compte de service) |
| Agents | SRVGLPI01 | TCP 80 | Inventaire (agent authentifié) |

Tout autre flux entrant vers SRVGLPI01 est refusé (UFW).

## Stockage de SRVGLPI01

| Miroir | Membres | Taille | Usage |
|---|---|---|---|
| md1 | sda1 + sdb1 | 10 Go | `/` (ext4) |
| md0 | sda5 + sdb5 | 2 Go | swap |
| md2 | sda6 + sdb6 | 9,5 Go | `/home` (ext4) |
| — | disque dédié, monté par UUID | 20 Go | `/backup` (ext4) |

- Table de partitions MBR, démarrage BIOS, **GRUB installé sur les deux disques**.
- `/home` séparé de `/` ; swap également en miroir.

## Annuaire

- Utilisateurs dans le conteneur par défaut `CN=Users`.
- Compte de service `svc-glpi` pour la liaison LDAP.
- Identifiant de connexion GLPI : `sAMAccountName` ; synchronisation : `objectGUID`.

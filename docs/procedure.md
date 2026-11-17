# 📋 Procédure — Serveur Debian en RAID 1 + GLPI relié à l'Active Directory

> Procédure complète et réutilisable, construite à partir du déploiement de la Menuiserie Valloire (entreprise fictive).
> Les valeurs entre `<…>` sont à adapter. Les valeurs du projet sont données en exemple.
> Chaque étape se termine par une **vérification** : ne passer à la suivante que si elle est ✅.

## Variables du projet (à remplir avant de commencer)

| Variable | Valeur du projet |
|---|---|
| `<RESEAU>` | 192.168.60.0/24 |
| `<PASSERELLE>` | 192.168.60.2 |
| `<IP_SRV>` (Debian) | 192.168.60.20 |
| `<IP_DC>` (Windows Server) | 192.168.60.250 |
| `<DOMAINE>` | stephanemetche.local |
| `<BASEDN>` | DC=stephanemetche,DC=local |
| `<USER>` (admin Linux) | stephane |
| `<PORT_SSH>` | 2222 |
| `<GLPI_VER>` / `<AGENT_VER>` | 12.0.2 / 1.21 |

---

## Phase 0 — Préparation

1. **Vérifier l'ISO** (poste Windows, dossier de l'ISO)
   ```powershell
   Get-FileHash .\debian-<ver>-amd64-netinst.iso -Algorithm SHA512
   & $gpg --verify SHA512SUMS.sign SHA512SUMS
   ```
   ✅ Empreinte identique à `SHA512SUMS` + « Bonne signature » de la Debian CD signing key.

2. **Créer la VM** : 2 Go RAM, 2 vCPU, réseau NAT, **2 disques identiques** (ex. 20 Go), firmware **BIOS**, ISO montée, « installer le système plus tard ».
   ✅ Les 2 disques apparaissent dans les paramètres.

---

## Phase 1 — Installation Debian en RAID 1

3. Installation **graphique**, langue/clavier FR, nom d'hôte, **domaine vide**, mot de passe root, utilisateur `<USER>`.
4. **Partitionnement : Manuel**
   1. Nouvelle table de partitions sur sda **et** sdb.
   2. Sur chaque disque : n°1 primaire 10 Go **amorçable**, n°5 logique 2 Go, n°6 logique le reste. **Toutes en « volume physique pour RAID »** (vérifier la lettre K, pas f).
   3. **Configurer le RAID logiciel** : 3 × RAID1, 2 actifs, 0 réserve : md0 = sda5+sdb5, md1 = sda1+sdb1, md2 = sda6+sdb6 (toujours le **même numéro** sur les deux disques).
   4. md0 → swap ; md1 → ext4 `/` ; md2 → ext4 `/home`.
   5. Terminer et appliquer.
   ✅ Le récapitulatif liste les 3 RAID1 et leurs formats.
5. Logiciels : **serveur SSH + utilitaires usuels** uniquement (pas d'interface graphique).
6. GRUB sur `/dev/sda`, fin d'installation, redémarrage.

---

## Phase 2 — Contrôle du RAID et test de panne

7. En root (console) :
   ```bash
   cat /proc/mdstat ; lsblk
   ```
   ✅ md0, md1, md2 en `[2/2] [UU]`. Si un miroir est `[U_]` : `mdadm --manage /dev/mdX --add /dev/sdXN`.
8. GRUB sur le second disque :
   ```bash
   grub-install /dev/sdb
   ```
   ✅ « Installation terminée, sans erreur ».
9. **Test de panne** : `poweroff` → **instantané** → retirer le disque 1 → démarrer.
   ✅ Le serveur démarre ; `/proc/mdstat` montre `[_U]`.
10. Remettre le disque (après un instantané : fichier **delta** `…-000001.vmdk`) → démarrer :
    ```bash
    mdadm --manage /dev/md1 --add /dev/sda1
    mdadm --manage /dev/md2 --add /dev/sda6
    watch -n1 cat /proc/mdstat
    ```
    ✅ Tous les miroirs en `[UU]`. Prendre un instantané « RAID-OK ».

---

## Phase 3 — Réseau, mises à jour, sudo

11. Diagnostic : `ip -br a ; ip r ; ping -c2 1.1.1.1 ; ping -c2 deb.debian.org`
12. Dépôt de sécurité (si l'installateur l'a désactivé) :
    ```bash
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    sed -i 's|^#\(deb.*security\)|\1|' /etc/apt/sources.list
    apt update && apt full-upgrade -y
    ```
13. sudo :
    ```bash
    apt install -y sudo
    usermod -aG sudo <USER>
    ```
    Se reconnecter avec `<USER>`. ✅ `sudo whoami` → `root`.
14. IP fixe (fichier `/etc/network/interfaces`, avec `.bak` avant) :
    ```
    auto ens33
    iface ens33 inet static
        address <IP_SRV>/24
        gateway <PASSERELLE>
    ```
    puis DNS :
    ```bash
    printf "nameserver <PASSERELLE>\nnameserver 1.1.1.1\n" | sudo tee /etc/resolv.conf
    sudo reboot
    ```
    ✅ `ip -br a` montre `<IP_SRV>` et `ping deb.debian.org` répond.

---

## Phase 4 — SSH durci

15. **Sur le client Windows** (`PS C:\…>`) :
    ```powershell
    ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\<nom_cle> -C "<USER>@<serveur>"
    type $env:USERPROFILE\.ssh\<nom_cle>.pub | ssh <USER>@<IP_SRV> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    ssh -i $env:USERPROFILE\.ssh\<nom_cle> <USER>@<IP_SRV>
    ```
    ✅ Connexion sans mot de passe.
16. **Sur le serveur**, garder cette session ouverte, créer `/etc/ssh/sshd_config.d/10-durcissement.conf` (Port, PermitRootLogin no, PasswordAuthentication no, AllowUsers…), puis :
    ```bash
    sudo sshd -t && sudo systemctl restart ssh
    ```
17. **Tester depuis une 2e fenêtre** : clé + nouveau port OK ; port 22, mot de passe et root refusés.
18. Raccourci côté client : bloc `Host` dans `%USERPROFILE%\.ssh\config` → `ssh <alias>`.

---

## Phase 5 — Pare-feu

19.
    ```bash
    sudo apt install -y ufw
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow <PORT_SSH>/tcp comment 'SSH'
    sudo ufw show added          # vérifier AVANT d'activer
    sudo ufw enable
    sudo ufw status verbose
    ```
    ✅ Nouvelle connexion SSH OK depuis une autre fenêtre.

---

## Phase 6 — Sauvegarde

20. Ajouter un disque (VM éteinte), puis **identifier le disque vide** :
    ```bash
    lsblk ; cat /proc/mdstat      # le disque cible ne doit apparaître dans AUCUN md
    ```
21. Préparer et monter **par UUID** :
    ```bash
    sudo parted /dev/<disque> --script mklabel gpt mkpart backup ext4 0% 100%
    sudo mkfs.ext4 -L BACKUP /dev/<disque>1
    sudo mkdir -p /backup
    UUID=$(sudo blkid -s UUID -o value /dev/<disque>1)
    echo "UUID=$UUID  /backup  ext4  defaults,nofail  0  2" | sudo tee -a /etc/fstab
    sudo systemctl daemon-reload && sudo mount -a && df -h /backup
    ```
22. Sauvegarder puis **tester la restauration** :
    ```bash
    sudo tar -czpf /backup/home/home-<USER>_$(date +%F_%H%M).tar.gz -C /home <USER>
    sudo tar -czpf /backup/systeme/systeme_$(date +%F_%H%M).tar.gz --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp --exclude=/mnt --exclude=/media --exclude=/backup --exclude=/lost+found /
    mkdir -p /tmp/test-restau
    sudo tar -xzpf /backup/systeme/systeme_*.tar.gz -C /tmp/test-restau etc/hostname
    diff /etc/hostname /tmp/test-restau/etc/hostname && echo OK
    ```

---

## Phase 7 — GLPI

23. Pile LAMP + port web :
    ```bash
    sudo apt install -y apache2 mariadb-server libapache2-mod-php php php-mysql php-mbstring php-curl php-gd php-xml php-intl php-ldap php-apcu php-zip php-bz2 php-bcmath php-opcache
    sudo ufw allow 80/tcp
    ```
24. Base et utilisateur dédiés (mot de passe saisi avec `read -s`) : `CREATE DATABASE glpi … utf8mb4`, `CREATE USER 'glpi'@'localhost'`, `GRANT ALL ON glpi.*`, `GRANT SELECT ON mysql.time_zone_name`, puis `mariadb-tzinfo-to-sql /usr/share/zoneinfo | sudo mariadb mysql`.
25. Déploiement :
    ```bash
    cd /tmp && wget https://github.com/glpi-project/glpi/releases/download/<GLPI_VER>/glpi-<GLPI_VER>.tgz
    sudo tar -xzf glpi-<GLPI_VER>.tgz -C /var/www/
    sudo chown -R www-data:www-data /var/www/glpi
    ```
26. VirtualHost `/etc/apache2/sites-available/glpi.conf` avec `DocumentRoot /var/www/glpi/public` + règles de réécriture vers `index.php` ; `session.cookie_httponly = On` ;
    ```bash
    sudo a2enmod rewrite && sudo a2dissite 000-default && sudo a2ensite glpi
    sudo apache2ctl configtest && sudo systemctl restart apache2
    ```
27. Navigateur → `http://<IP_SRV>` : prérequis ✅ → base `localhost` / `glpi` → base existante `glpi` → fin.
28. **Sécurisation immédiate** : `sudo rm /var/www/glpi/install/install.php`, mot de passe de `glpi` changé (et **noté**), `tech` / `normal` / `post-only` désactivés.
    ✅ Plus de bandeau d'alerte sur l'accueil.

---

## Phase 8 — Préparation du contrôleur de domaine

29. Vérifier IP fixe, **passerelle**, un **seul DHCP** sur le réseau :
    ```powershell
    ipconfig /all ; Get-DhcpServerv4Scope ; Get-NetRoute -DestinationPrefix 0.0.0.0/0
    ```
30. Zone inversée + enregistrements du serveur GLPI :
    ```powershell
    Add-DnsServerPrimaryZone -NetworkId "<RESEAU>" -ReplicationScope Domain
    Add-DnsServerResourceRecordA -ZoneName "<DOMAINE>" -Name "<serveur>" -IPv4Address <IP_SRV> -CreatePtr
    ```
31. Utilisateurs + compte de service (`New-ADUser`, mot de passe saisi masqué).
    ✅ `Get-ADUser -SearchBase "CN=Users,<BASEDN>" -SearchScope OneLevel`.

---

## Phase 9 — Liaison LDAP

32. **Tester depuis Debian avant GLPI** :
    ```bash
    timeout 3 bash -c '</dev/tcp/<IP_DC>/389' && echo OUVERT
    sudo apt install -y ldap-utils
    ldapsearch -x -H ldap://<IP_DC> -D "svc-glpi@<DOMAINE>" -W -b "<BASEDN>" "(sAMAccountName=<un_user>)" cn
    ```
    - `49 / 52e` → mot de passe ; `Strong(er) authentication required` → GPO signature LDAP (Windows Server 2025) ou LDAPS.
    ✅ `result: 0 Success`.
33. GLPI → Configuration > Authentification > Annuaires LDAP > Ajouter (préconfiguration Active Directory) : serveur, port, BaseDN, filtre, bind, `samaccountname`, `objectguid`, **Activé = Oui**, mot de passe du compte de service.
    ✅ Onglet **Tester** : 5 coches vertes.
34. Import : `http://<IP_SRV>/front/ldap.php` → Importation de nouveaux utilisateurs → Rechercher → cocher → Actions > Importer.
    ✅ Connexion d'un utilisateur AD (source = annuaire). Compte local `glpi` : source **Base interne GLPI**.

---

## Phase 10 — Inventaire

35. GLPI → Administration > Inventaire : **Activer** + authentification des agents (identifiant/mot de passe dédiés) → **Sauvegarder**.
36. Debian :
    ```bash
    wget https://github.com/glpi-project/glpi-agent/releases/download/<AGENT_VER>/glpi-agent-<AGENT_VER>-linux-installer.pl
    sudo perl glpi-agent-<AGENT_VER>-linux-installer.pl --server=http://<IP_SRV>/ --runnow
    # identifiants de l'agent dans /etc/glpi-agent/conf.d/20-auth.cfg (user / password), chmod 600
    sudo glpi-agent --force
    ```
37. Windows (PowerShell admin **sur la machine cible**) : `msiexec /i GLPI-Agent-<AGENT_VER>-x64.msi /quiet SERVER=http://<IP_SRV>/ USER=… PASSWORD=… RUNNOW=1`.
    ✅ Les deux machines dans Parc > Ordinateurs.

---

## Check-list finale
- [ ] `/proc/mdstat` : tous les miroirs `[UU]`, GRUB sur les 2 disques
- [ ] IP fixe + DNS, système à jour, dépôt security actif
- [ ] SSH : clé uniquement, root interdit, port dédié, testé
- [ ] UFW actif, seuls les ports nécessaires ouverts
- [ ] Sauvegarde sur disque dédié (UUID) + restauration testée
- [ ] GLPI : install.php supprimé, comptes par défaut traités, mots de passe notés
- [ ] LDAP au vert, import fait, connexion AD testée
- [ ] Inventaire Windows + Linux visible dans le parc
- [ ] Limites documentées (LDAPS, sauvegarde hors site/hors ligne)

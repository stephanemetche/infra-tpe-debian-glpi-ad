# Contrôles RAID (mdadm)

| Commande | Rôle |
|---|---|
| `cat /proc/mdstat` | État des miroirs : `[UU]` OK, `[U_]` dégradé |
| `mdadm --detail /dev/md1` | Détail d'un miroir |
| `mdadm --manage /dev/md1 --add /dev/sda1` | Réintégrer un membre |
| `watch -n1 cat /proc/mdstat` | Suivre la reconstruction |
| `grub-install /dev/sdb` | Rendre le second disque amorçable |

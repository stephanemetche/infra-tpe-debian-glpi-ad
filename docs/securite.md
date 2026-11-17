# 🛡️ Choix de sécurité, compromis et améliorations

## Principes appliqués

| Principe | Mise en œuvre |
|---|---|
| **Moindre privilège** | Administration via `sudo` (tracée) ; utilisateur SQL limité à la base `glpi` ; compte de service AD en lecture pour GLPI (jamais l'administrateur du domaine) |
| **Réduction de la surface d'attaque** | Serveur sans interface graphique ; seuls les ports 2222 (SSH) et 80 (GLPI) ouverts ; tunnels SSH désactivés |
| **Authentification forte** | SSH par clé ed25519 uniquement ; agents GLPI authentifiés |
| **Défense en profondeur** | RAID (disponibilité) + sauvegardes (récupération) + pare-feu + durcissement des services |
| **Tester avant d'appliquer** | `sshd -t`, `apache2ctl configtest`, `ufw show added`, `ldapsearch` avant GLPI |
| **Secrets protégés** | Saisie masquée (`read -s`, `-AsSecureString`), fichier d'identifiants de l'agent en `600`, aucun secret dans ce dépôt |

## SSH — `configs/sshd/10-durcissement.conf`

| Réglage | Menace couverte |
|---|---|
| `PasswordAuthentication no` | Force brute sur les mots de passe |
| `PermitRootLogin no` | Ciblage du compte le plus puissant |
| `AllowUsers` | Connexion avec un compte oublié ou compromis |
| `MaxAuthTries 3`, `LoginGraceTime 30` | Essais répétés, connexions pendantes |
| `Port 2222` | Bruit des scans automatiques (réduction, pas une protection) |

## GLPI

- Seul `public/` est exposé ; `config/` et `files/` restent hors du web.
- `session.cookie_httponly` activé (vol de session par script).
- `install.php` supprimé ; comptes par défaut désactivés ou mot de passe changé.
- Télémétrie désactivée (minimisation des flux sortants).

## Compromis assumés dans le lab

| Compromis | Risque | Amélioration prévue |
|---|---|---|
| LDAP en clair (389), signature LDAP assouplie par GPO | Le mot de passe du compte de service peut être intercepté sur le réseau | **LDAPS (636)** avec certificat émis par **AD CS** (auto-enrôlement par GPO), puis rétablir l'exigence de signature |
| GLPI en HTTP | Identifiants des utilisateurs en clair | **HTTPS** (certificat interne), redirection HTTP → HTTPS |
| Sauvegarde sur un disque de la même VM | Perte en cas de sinistre ou de rançongiciel | Copie **hors site** + copie **hors ligne/immuable**, planification, **chiffrement**, rotation |
| Comptes de test à mot de passe sans expiration | Mots de passe figés | Politique de mots de passe du domaine, réservée aux comptes de service |

## Règle 3-2-1-1-0 — où en est le projet

| Règle | État |
|---|---|
| 3 copies | ⚠️ 2 (production + disque de sauvegarde) |
| 2 supports | ⚠️ même machine virtuelle |
| 1 hors site | ❌ à mettre en place |
| 1 hors ligne / immuable | ❌ à mettre en place |
| 0 erreur à la restauration | ✅ restauration testée et comparée avec `diff` |

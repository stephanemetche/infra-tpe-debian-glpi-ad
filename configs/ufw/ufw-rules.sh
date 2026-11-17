#!/usr/bin/env bash
# Règles UFW de SRVGLPI01 - principe : tout refuser en entrée, n'ouvrir que le nécessaire.
# IMPORTANT : autoriser le port SSH réel AVANT d'activer le pare-feu.
set -euo pipefail

ufw default deny incoming
ufw default allow outgoing
ufw allow 2222/tcp comment 'SSH durci'   # "ufw allow ssh" ouvrirait le 22 et couperait l'accès
ufw allow 80/tcp   comment 'HTTP GLPI'
ufw show added                           # relire avant d'activer
ufw --force enable
ufw status verbose

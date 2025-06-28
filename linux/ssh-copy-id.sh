#!/bin/bash

# -------------------------------------------------------------------
# SSH Copy ID Script
#
# Version: 0.0.1
# Author: Torayld
# Date: 2025-06-28
# Description: This script sets up SSH key-based authentication for a remote host.
# It generates an SSH key pair if not present, checks the remote home directory,
# verifies SSH configuration, and copies the public key to the remote host.
# It also ensures the correct permissions for the SSH keys and home directory.
# Usage: ./ssh-copy-id.sh user@host mot_de_passe_sudo [port] [chemin_cle_privée]
# Requirements: SSH access to the remote host, sudo privileges, and a valid SSH key pair.
# -------------------------------------------------------------------

# Script version
SCRIPT_VERSION="0.0.1"

#!/bin/bash

# Usage : ./script.sh user@host mot_de_passe_sudo [port] [chemin_cle_privée]

if [ $# -lt 2 ]; then
  echo "Usage: $0 user@host mot_de_passe_sudo [port] [chemin_cle_privée]"
  exit 1
fi

USER_HOST="$1"
SUDO_PASS="$2"
PORT="${3:-22}"
KEY_PRIV="${4:-$HOME/.ssh/id_rsa}"
KEY_PUB="${KEY_PRIV}.pub"

USER_NAME="${USER_HOST%@*}"

# Génère la clé SSH si elle n'existe pas
if [ ! -f "$KEY_PRIV" ]; then
  echo "🔑 Clé privée SSH introuvable à $KEY_PRIV, génération d'une nouvelle clé..."
  ssh-keygen -t rsa -b 4096 -f "$KEY_PRIV" -N "" || { echo "❌ Échec de la génération de la clé SSH"; exit 2; }
fi

# 🔐 Sécurisation des permissions de la clé privée/public et du dossier .ssh local
echo "🔒 Vérification et correction des permissions de la clé SSH locale..."
chmod 700 "$(dirname "$KEY_PRIV")"
chmod 600 "$KEY_PRIV"
chmod 644 "$KEY_PUB"

if [ ! -f "$KEY_PUB" ]; then
  echo "❌ Clé publique introuvable à $KEY_PUB, erreur"
  exit 3
fi

PUBKEY_CONTENT=$(<"$KEY_PUB")

echo "🔍 Vérification et création éventuelle du dossier home distant /var/services/homes/$USER_NAME..."

ssh -p "$PORT" "$USER_HOST" /bin/bash -s << EOF
echo "$SUDO_PASS" | sudo -S test -d /var/services/homes/$USER_NAME
if [ \$? -ne 0 ]; then
  echo "⚠️ Le dossier /var/services/homes/$USER_NAME n'existe pas, création..."
  echo "$SUDO_PASS" | sudo -S mkdir -p /var/services/homes/$USER_NAME
  echo "$SUDO_PASS" | sudo -S chown $USER_NAME /var/services/homes/$USER_NAME
  echo "$SUDO_PASS" | sudo -S chmod 700 /var/services/homes/$USER_NAME
else
  echo "✅ Le dossier /var/services/homes/$USER_NAME existe."
fi
EOF

echo "🔍 Vérification de la configuration SSH sur $USER_HOST..."

ssh -p "$PORT" "$USER_HOST" "echo '$SUDO_PASS' | sudo -S grep -qE '^[[:space:]]*PubkeyAuthentication[[:space:]]+yes' /etc/ssh/sshd_config"
if [ $? -ne 0 ]; then
  echo "❌ PubkeyAuthentication yes est absent ou commenté"
  exit 4
fi

ssh -p "$PORT" "$USER_HOST" "echo '$SUDO_PASS' | sudo -S grep -qE '^[[:space:]]*AuthorizedKeysFile[[:space:]]+\S+' /etc/ssh/sshd_config"
if [ $? -ne 0 ]; then
  echo "❌ AuthorizedKeysFile est absent ou commenté"
  exit 5
fi

echo "✅ Configuration SSH correcte"

echo "🔐 Copie de la clé publique vers $USER_HOST... (mot de passe SSH demandé si nécessaire)"
ssh -p "$PORT" "$USER_HOST" bash -c "'
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  grep -qF \"$PUBKEY_CONTENT\" ~/.ssh/authorized_keys 2>/dev/null || echo \"$PUBKEY_CONTENT\" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
'"

echo "🔗 Test de la connexion SSH sans mot de passe..."
ssh -p "$PORT" "$USER_HOST" "echo '✅ Connexion SSH réussie à \$(hostname)'"

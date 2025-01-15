#!/bin/bash

# Fonction pour demander une valeur 
prompt_for_value() {
  local var_name="$1"
  local prompt_message="$2"
  local default_value="$3"

  read -p "$prompt_message [${default_value}]: " value
  echo "${value:-$default_value}"
}

# Vérifiez si le script est exécuté dans un répertoire Git
if [ ! -d ".git" ]; then
  echo "Ce répertoire n'est pas un dépôt Git."
  exit 1
fi

# Vérifiez si Ansible est installé
if ! command -v ansible-playbook &> /dev/null; then
  echo "Ansible n'est pas installé. Installation en cours..."
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y ansible
  elif command -v yum &> /dev/null; then
    sudo yum install -y ansible
  else
    echo "Impossible de détecter le gestionnaire de paquets pour installer Ansible. Veuillez l'installer manuellement."
    exit 1
  fi
fi

# Fichiers de configuration
general_config_file="/home/tolliam/starlightcoder/speenea/script/cinit.conf"
custom_config_file="./cinit.conf"
hosts_file="/home/tolliam/starlightcoder/speenea/script/hosts/hosts"

# Vérifiez si le fichier de configuration générale existe
if [ ! -f "$general_config_file" ]; then
  echo "Fichier de configuration générale $general_config_file introuvable. Création en cours..."
  github_secret_key=$(prompt_for_value "github_secret_key" "Entrez la clé secrète GitHub" "")
  echo "github_secret_key=$github_secret_key" > "$general_config_file"
else
  source "$general_config_file"

  if [ -z "$github_secret_key" ]; then
    github_secret_key=$(prompt_for_value "github_secret_key" "Entrez la clé secrète GitHub" "")
    echo "github_secret_key=$github_secret_key" > "$general_config_file"
  fi
fi

# Vérifiez si le fichier de configuration custom existe
if [ ! -f "$custom_config_file" ]; then
  echo "Fichier de configuration custom $custom_config_file introuvable. Création en cours..."
  workspace=$(prompt_for_value "workspace" "Entrez le chemin du workspace" "/chemin/vers/workspace")
  key_path=$(prompt_for_value "key_path" "Entrez le répertoire où enregistrer les clés générées" "")
  dest_server=$(prompt_for_value "dest_server" "Entrez le serveur de déploiement" "")
  dest_server_group_name=$(prompt_for_value "dest_server_group_name" "Entrez le groupe de serveurs (laisser vide pour 'default')" "default")

  echo "workspace=$workspace" > "$custom_config_file"
  echo "key_path=$key_path" >> "$custom_config_file"
  echo "dest_server=$dest_server" >> "$custom_config_file"
  echo "dest_server_group_name=$dest_server_group_name" >> "$custom_config_file"
else
  source "$custom_config_file"

  if [ -z "$workspace" ]; then
    workspace=$(prompt_for_value "workspace" "Entrez le chemin du workspace" "/chemin/vers/workspace")
    echo "workspace=$workspace" >> "$custom_config_file"
  fi

  if [ -z "$key_path" ]; then
    key_path=$(prompt_for_value "key_path" "Entrez le répertoire où enregistrer les clés générées" "")
    echo "key_path=$key_path" >> "$custom_config_file"
  fi

  if [ -z "$dest_server" ] && [ -z "$dest_server_group_name" ]; then
    dest_server=$(prompt_for_value "dest_server" "Entrez le serveur de déploiement" "")
    dest_server_group_name=$(prompt_for_value "dest_server_group_name" "Entrez le groupe de serveurs (laisser vide pour 'default')" "default")
    echo "dest_server=$dest_server" >> "$custom_config_file"
    echo "dest_server_group_name=$dest_server_group_name" >> "$custom_config_file"
  fi

  # Définit la destination finale
  if [ -n "$dest_server" ]; then
    dest="$dest_server"
  else
    dest="$dest_server_group_name"
  fi
fi

# Vérifiez si le fichier hosts existe
if [ ! -f "$hosts_file" ]; then
  echo "Fichier hosts introuvable. Création en cours..."
  touch "$hosts_file"
fi

# Vérifiez si la configuration pour dest_server ou dest_server_group_name existe
if [ -n "$dest_server_group_name" ] && ! grep -q "^\[$dest_server_group_name\]" "$hosts_file"; then
  echo "Configuration pour le groupe $dest_server_group_name introuvable. Création en cours..."
  echo "" >> "$hosts_file"
  echo "[$dest_server_group_name]" >> "$hosts_file"
fi

if [ -n "$dest_server" ] && ! grep -q "$dest_server" "$hosts_file"; then
  echo "Configuration pour le serveur $dest_server introuvable. Création en cours..."
  user=$(prompt_for_value "user" "Entrez le nom d'utilisateur Ansible" "")
  password=$(prompt_for_value "password" "Entrez le mot de passe Ansible" "")

  echo "$dest_server ansible_user=$user ansible_password=$password" >> "$hosts_file"
fi

# Récupérer l'URL du dépôt distant
remote_url=$(git config --get remote.origin.url)

# Extraire le propriétaire et le nom du dépôt à partir de l'URL
if [[ $remote_url =~ ^https://github.com/([^/]+)/([^/.]+) ]]; then
  owner="${BASH_REMATCH[1]}"
  repo_name="${BASH_REMATCH[2]}"
elif [[ $remote_url =~ ^git@github.com:([^/]+)/([^/.]+) ]]; then
  owner="${BASH_REMATCH[1]}"
  repo_name="${BASH_REMATCH[2]}"
else
  echo "Impossible de détecter l'URL du dépôt Git."
  exit 1
fi

# Récupérer le nom de la branche actuelle
branch_name=$(git rev-parse --abbrev-ref HEAD)

# Exécuter le playbook Ansible
ansible-playbook -i "$hosts_file" \
/home/tolliam/starlightcoder/speenea/script/playbook/CI_init.yml \
-e "repo_name=$repo_name branch_name=$branch_name owner=$owner workspace=$workspace key_path=$key_path dest=$dest github_secret_key=$github_secret_key"

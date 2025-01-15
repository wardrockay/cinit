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

# Chargement ou création des fichiers de configuration
github_secret_key=""
workspace=""
key_path=""
dest_server=""
dest_server_group_name=""

if [ -f "$general_config_file" ]; then
  source "$general_config_file"
else
  github_secret_key=$(prompt_for_value "github_secret_key" "Entrez la clé secrète GitHub" "")
  echo "github_secret_key=$github_secret_key" > "$general_config_file"
fi

if [ -f "$custom_config_file" ]; then
  source "$custom_config_file"
fi

# Vérifiez et demandez les valeurs manquantes pour workspace et key_path
if [ -z "$workspace" ]; then
  workspace=$(prompt_for_value "workspace" "Entrez le chemin du workspace" "/chemin/vers/workspace")
  echo "workspace='$workspace'" >> "$custom_config_file"
fi

if [ -z "$key_path" ]; then
  key_path=$(prompt_for_value "key_path" "Entrez le répertoire où enregistrer les clés générées" "")
  echo "key_path='$key_path'" >> "$custom_config_file"
fi

# Fonction pour gérer le cas des serveurs et groupes
configure_dest() {
  if [ -n "$dest_server" ]; then
    if grep -q "$dest_server" "$hosts_file"; then
      dest="$dest_server"
    else
      user=$(prompt_for_value "user" "Entrez le nom d'utilisateur Ansible" "")
      password=$(prompt_for_value "password" "Entrez le mot de passe Ansible" "")
      dest_server_group_name=$(prompt_for_value "dest_server_group_name" "Entrez le groupe de serveurs (laisser vide pour 'default')" "default")
      
      if [ "$dest_server_group_name" == "default" ]; then
        echo "[default]" >> "$hosts_file"
      else
        echo "[$dest_server_group_name]" >> "$hosts_file"
      fi
      
      echo "$dest_server ansible_user=$user ansible_password=$password" >> "$hosts_file"
      dest="$dest_server"
    fi
  elif [ -n "$dest_server_group_name" ]; then
    if grep -q "^\[$dest_server_group_name\]" "$hosts_file"; then
      dest="$dest_server_group_name"
    else
      dest_server=$(prompt_for_value "dest_server" "Entrez le serveur de déploiement" "")
      user=$(prompt_for_value "user" "Entrez le nom d'utilisateur Ansible" "")
      password=$(prompt_for_value "password" "Entrez le mot de passe Ansible" "")
      echo "[$dest_server_group_name]" >> "$hosts_file"
      echo "$dest_server ansible_user=$user ansible_password=$password" >> "$hosts_file"
      dest="$dest_server_group_name"
    fi
  else
    dest_server=$(prompt_for_value "dest_server" "Entrez le serveur de déploiement" "")
    user=$(prompt_for_value "user" "Entrez le nom d'utilisateur Ansible" "")
    password=$(prompt_for_value "password" "Entrez le mot de passe Ansible" "")
    dest_server_group_name=$(prompt_for_value "dest_server_group_name" "Entrez le groupe de serveurs (laisser vide pour 'default')" "default")

    if [ "$dest_server_group_name" == "default" ]; then
      echo "[default]" >> "$hosts_file"
    else
      echo "[$dest_server_group_name]" >> "$hosts_file"
    fi

    echo "$dest_server ansible_user=$user ansible_password=$password" >> "$hosts_file"

    read -p "Voulez-vous cibler le groupe ou le serveur individuel ? (groupe/serveur): " target_choice
    if [ "$target_choice" == "groupe" ]; then
      dest="$dest_server_group_name"
      echo "dest_server_group_name=$dest_server_group_name" >> "$custom_config_file"
    else
      dest="$dest_server"
      echo "dest_server=$dest_server" >> "$custom_config_file"
    fi
  fi
}

configure_dest

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
#!/bin/bash
# shellcheck source=/dev/null

set -e

########################################################
# 
#  Script de Instalação do Pterodactyl-AutoThemes
#  Adaptado para uso pela Rest Api Sistemas
#
########################################################

# Obtenha a versão mais recente antes de executar o script #

get_release() {
curl --silent \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/Ferks-FK/ControlPanel-Installer/releases/latest |
  grep '"tag_name":' |
  sed -E 's/.*"([^"]+)".*/\1/'
}

# Variables #
SCRIPT_RELEASE="$(get_release)"
SUPPORT_LINK="https://discord.gg/buDBbSGJmQ"
WIKI_LINK="https://github.com/Ferks-FK/ControlPanel-Installer/wiki"
GITHUB_URL="https://raw.githubusercontent.com/Ferks-FK/ControlPanel.gg-Installer/$SCRIPT_RELEASE"
RANDOM_PASSWORD="$(openssl rand -base64 32)"
MYSQL_PASSWORD=false
CONFIGURE_SSL=false
INFORMATIONS="/var/log/ControlPanel-Info"
FQDN=""

update_variables() {
CLIENT_VERSION="$(grep "'version'" "/var/www/controlpanel/config/app.php" | cut -c18-25 | sed "s/[',]//g")"
LATEST_VERSION="$(curl -s https://raw.githubusercontent.com/Ctrlpanel-gg/panel/main/config/app.php | grep "'version'" | cut -c18-25 | sed "s/[',]//g")"
}

# Visual Functions #
print_brake() {
  for ((n = 0; n < $1; n++)); do
    echo -n "#"
  done
  echo ""
}

print_warning() {
  echo ""
  echo -e "* ${YELLOW}WARNING${RESET}: $1"
  echo ""
}

print_error() {
  echo ""
  echo -e "* ${RED}ERROR${RESET}: $1"
  echo ""
}

print_success() {
  echo ""
  echo -e "* ${GREEN}SUCCESS${RESET}: $1"
  echo ""
}

print() {
  echo ""
  echo -e "* ${GREEN}$1${RESET}"
  echo ""
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

# Colors #
GREEN="\e[0;92m"
YELLOW="\033[1;33m"
RED='\033[0;31m'
RESET="\e[0m"

EMAIL_RX="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"

valid_email() {
  [[ $1 =~ ${EMAIL_RX} ]]
}

email_input() {
  local __resultvar=$1
  local result=''

  while ! valid_email "$result"; do
    echo -n "* ${2}"
    read -r result

    valid_email "$result" || print_error "${3}"
  done

  eval "$__resultvar="'$result'""
}

password_input() {
  local __resultvar=$1
  local result=''
  local default="$4"

  while [ -z "$result" ]; do
    echo -n "* ${2}"
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && {
        printf '\n'
        break
      }
      if [[ $char == $'\x7f' ]]; then
        if [ -n "$result" ]; then
          [[ -n $result ]] && result=${result%?}
          printf '\b \b'
        fi
      else
        result+=$char
        printf '*'
      fi
    done
    [ -z "$result" ] && [ -n "$default" ] && result="$default"
    [ -z "$result" ] && print_error "${3}"
  done

  eval "$__resultvar="'$result'""
}

# Verificação do sistema operacional #
check_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  elif [ -f /etc/SuSe-release ]; then
    OS="SuSE"
    OS_VER="?"
  elif [ -f /etc/redhat-release ]; then
    OS="Red Hat/CentOS"
    OS_VER="?"
  else
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
}

only_upgrade_panel() {
print "Atualizando o seu painel, por favor, aguarde..."

cd /var/www/controlpanel
php artisan down

git stash
git pull

[ "$OS" == "centos" ] && export PATH=/usr/local/bin:$PATH
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

php artisan migrate --seed --force

php artisan view:clear
php artisan config:clear

set_permissions

php artisan queue:restart

php artisan up

print "Seu painel foi atualizado com sucesso para a versão ${YELLOW}${LATEST_VERSION}${RESET}."
exit 1
}

enable_services_debian_based() {
systemctl enable mariadb --now
systemctl enable redis-server --now
systemctl enable nginx
}

enable_services_centos_based() {
systemctl enable mariadb --now
systemctl enable redis --now
systemctl enable nginx
}

allow_selinux() {
setsebool -P httpd_can_network_connect 1 || true
setsebool -P httpd_execmem 1 || true
setsebool -P httpd_unified 1 || true
}

centos_php() {
curl -so /etc/php-fpm.d/www-controlpanel.conf "$GITHUB_URL"/configs/www-controlpanel.conf

systemctl enable php-fpm --now
}

check_compatibility() {
print "Verificando se o seu sistema é compatível com o script..."
sleep 2

case "$OS" in
    debian)
      PHP_SOCKET="/run/php/php8.1-fpm.sock"
      [ "$OS_VER_MAJOR" == "9" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "11" ] && SUPPORTED=true
    ;;
    ubuntu)
      PHP_SOCKET="/run/php/php8.1-fpm.sock"
      [ "$OS_VER_MAJOR" == "18" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "20" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "22" ] && SUPPORTED=true
    ;;
    centos)
      PHP_SOCKET="/var/run/php-fpm/controlpanel.sock"
      [ "$OS_VER_MAJOR" == "7" ] && SUPPORTED=true
      [ "$OS_VER_MAJOR" == "8" ] && SUPPORTED=true
    ;;
    *)
        SUPPORTED=false
    ;;
esac

if [ "$SUPPORTED" == true ]; then
    print "$OS $OS_VER é suportado!"
  else
    print_error "$OS $OS_VER não é suportado!"
    exit 1
fi
}


ask_ssl() {
echo -ne "* Deseja configurar SSL para o seu domínio? (s/N): "
read -r CONFIGURE_SSL
if [[ "$CONFIGURE_SSL" == [Ss] ]]; then
    CONFIGURE_SSL=true
    email_input EMAIL "Digite seu endereço de e-mail para criar o certificado SSL para o seu domínio: " "E-mail não pode ser vazio ou inválido!"
fi
}

install_composer() {
print "Instalando o Composer..."

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
}

download_files() {
print "Baixando Arquivos Necessários..."

git clone -q https://github.com/Ctrlpanel-gg/panel.git /var/www/controlpanel
rm -rf /var/www/controlpanel/.env.example
curl -so /var/www/controlpanel/.env.example "$GITHUB_URL"/configs/.env.example

cd /var/www/controlpanel
[ "$OS" == "centos" ] && export PATH=/usr/local/bin:$PATH
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
}

set_permissions() {
print "Configurando Permissões Necessárias..."

case "$OS" in
  debian | ubuntu)
    chown -R www-data:www-data /var/www/controlpanel/
  ;;
  centos)
    chown -R nginx:nginx /var/www/controlpanel/
  ;;
esac

cd /var/www/controlpanel
chmod -R 755 storage/* bootstrap/cache/
}

configure_environment() {
print "Configurando o arquivo base..."

sed -i -e "s@<timezone>@$TIMEZONE@g" /var/www/controlpanel/.env.example
sed -i -e "s@<db_host>@$DB_HOST@g" /var/www/controlpanel/.env.example
sed -i -e "s@<db_port>@$DB_PORT@g" /var/www/controlpanel/.env.example
sed -i -e "s@<db_name>@$DB_NAME@g" /var/www/controlpanel/.env.example
sed -i -e "s@<db_user>@$DB_USER@g" /var/www/controlpanel/.env.example
sed -i -e "s|<db_pass>|$DB_PASS|g" /var/www/controlpanel/.env.example
}

check_database_info() {
# Verifica se o MySQL tem uma senha
if ! mysql -u root -e "SHOW DATABASES;" &>/dev/null; then
  MYSQL_PASSWORD=true
  print_warning "Parece que o seu MySQL tem uma senha, por favor, digite-a agora"
  password_input MYSQL_ROOT_PASS "Senha do MySQL: " "Senha não pode ser vazia!"
  if mysql -u root -p"$MYSQL_ROOT_PASS" -e "SHOW DATABASES;" &>/dev/null; then
      print "A senha está correta, continuando..."
    else
      print_warning "A senha não está correta, por favor, digite a senha novamente"
      check_database_info
  fi
fi

# Verifica se o usuário escolhido já existe
if [ "$MYSQL_PASSWORD" == true ]; then
    mysql -u root -p"$MYSQL_ROOT_PASS" -e "SELECT User FROM mysql.user;" 2>/dev/null >> "$INFORMATIONS/check_user.txt"
  else
    mysql -u root -e "SELECT User FROM mysql.user;" 2>/dev/null >> "$INFORMATIONS/check_user.txt"
fi
sed -i '1d' "$INFORMATIONS/check_user.txt"
while grep -q "$DB_USER" "$INFORMATIONS/check_user.txt"; do
  print_warning "Oops, parece que o usuário ${GREEN}$DB_USER${RESET} já existe no seu MySQL, por favor, use outro."
  echo -n "* Usuário do Banco de Dados: "
  read -r DB_USER
done
rm -r "$INFORMATIONS/check_user.txt"


# Verificar se o banco de dados já existe no MySQL
if [ "$MYSQL_PASSWORD" == true ]; then
    mysql -u root -p"$MYSQL_ROOT_PASS" -e "SHOW DATABASES;" 2>/dev/null >> "$INFORMATIONS/check_db.txt"
  else
    mysql -u root -e "SHOW DATABASES;" 2>/dev/null >> "$INFORMATIONS/check_db.txt"
fi
sed -i '1d' "$INFORMATIONS/check_db.txt"
while grep -q "$DB_NAME" "$INFORMATIONS/check_db.txt"; do
  print_warning "Oops, parece que o banco de dados ${GREEN}$DB_NAME${RESET} já existe no seu MySQL, por favor, use outro nome."
  echo -n "* Nome do Banco de Dados: "
  read -r DB_NAME
done
rm -r "$INFORMATIONS/check_db.txt"
}

configure_database() {
print "Configurando o Banco de Dados..."

if [ "$MYSQL_PASSWORD" == true ]; then
    mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE ${DB_NAME};" &>/dev/null
    mysql -u root -p"$MYSQL_ROOT_PASS" -e "CREATE USER '${DB_USER}'@'${DB_HOST}' IDENTIFICADO POR '${DB_PASS}';" &>/dev/null
    mysql -u root -p"$MYSQL_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DB_HOST}';" &>/dev/null
    mysql -u root -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;" &>/dev/null
  else
    mysql -u root -e "CREATE DATABASE ${DB_NAME};"
    mysql -u root -e "CREATE USER '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASS}';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DB_HOST}';"
    mysql -u root -e "FLUSH PRIVILEGES;"
fi
}

configure_webserver() {
print "Configurando o Servidor Web..."

if [ "$CONFIGURE_SSL" == true ]; then
    WEB_FILE="controlpanel_ssl.conf"
  else
    WEB_FILE="controlpanel.conf"
fi

case "$OS" in
  debian | ubuntu)
    rm -rf /etc/nginx/sites-enabled/default

    curl -so /etc/nginx/sites-available/controlpanel.conf "$GITHUB_URL"/configs/$WEB_FILE

    sed -i -e "s@<domain>@$FQDN@g" /etc/nginx/sites-available/controlpanel.conf

    sed -i -e "s@<php_socket>@$PHP_SOCKET@g" /etc/nginx/sites-available/controlpanel.conf

    [ "$OS" == "debian" ] && [ "$OS_VER_MAJOR" == "9" ] && sed -i -e 's/ TLSv1.3//' /etc/nginx/sites-available/controlpanel.conf

    ln -s /etc/nginx/sites-available/controlpanel.conf /etc/nginx/sites-enabled/controlpanel.conf
  ;;
  centos)
    rm -rf /etc/nginx/conf.d/default

    curl -so /etc/nginx/conf.d/controlpanel.conf "$GITHUB_URL"/configs/$WEB_FILE

    sed -i -e "s@<domain>@$FQDN@g" /etc/nginx/conf.d/controlpanel.conf

    sed -i -e "s@<php_socket>@$PHP_SOCKET@g" /etc/nginx/conf.d/controlpanel.conf
  ;;
esac

# Matar o nginx se estiver ouvindo na porta 80 antes de iniciar, corrigido um bug de uso de porta.
if netstat -tlpn | grep 80 &>/dev/null; then
  killall nginx
fi

if [ "$(systemctl is-active --quiet nginx)" == "active" ]; then
    systemctl restart nginx
  else
    systemctl start nginx
fi
}


configure_firewall() {
print "Configurando o firewall..."

case "$OS" in
  debian | ubuntu)
    apt-get install -qq -y ufw

    ufw allow ssh &>/dev/null
    ufw allow http &>/dev/null
    ufw allow https &>/dev/null

    ufw --force enable &>/dev/null
    ufw --force reload &>/dev/null
  ;;
  centos)
    yum update -y -q

    yum -y -q install firewalld &>/dev/null

    systemctl --now enable firewalld &>/dev/null

    firewall-cmd --add-service=http --permanent -q
    firewall-cmd --add-service=https --permanent -q
    firewall-cmd --add-service=ssh --permanent -q
    firewall-cmd --reload -q
  ;;
esac
}

configure_ssl() {
print "Configurando SSL..."

FAILED=false

if [ "$(systemctl is-active --quiet nginx)" == "inactive" ] || [ "$(systemctl is-active --quiet nginx)" == "failed" ]; then
  systemctl start nginx
fi

case "$OS" in
  debian | ubuntu)
    apt-get update -y -qq && apt-get upgrade -y -qq
    apt-get install -y -qq certbot && apt-get install -y -qq python3-certbot-nginx
  ;;
  centos)
    [ "$OS_VER_MAJOR" == "7" ] && yum -y -q install certbot python-certbot-nginx
    [ "$OS_VER_MAJOR" == "8" ] && yum -y -q install certbot python3-certbot-nginx
  ;;
esac

certbot certonly --nginx --non-interactive --agree-tos --quiet --no-eff-email --email "$EMAIL" -d "$FQDN" || FAILED=true

if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    if [ "$(systemctl is-active --quiet nginx)" == "active" ]; then
      systemctl stop nginx
    fi
    print_warning "O script falhou ao gerar automaticamente o certificado SSL, tentando um comando alternativo..."
    FAILED=false

    certbot certonly --standalone --non-interactive --agree-tos --quiet --no-eff-email --email "$EMAIL" -d "$FQDN" || FAILED=true

    if [ -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == false ]; then
        print "O script conseguiu gerar com sucesso o certificado SSL!"
      else
        print_warning "O script falhou ao gerar o certificado, tente fazer isso manualmente."
    fi
  else
    print "O script conseguiu gerar com sucesso o certificado SSL!"
fi
}


configure_crontab() {
print "Configurando Crontab"

crontab -l | {
  cat
  echo "* * * * * php /var/www/controlpanel/artisan schedule:run >> /dev/null 2>&1"
} | crontab -
}

configure_service() {
print "Configurando o Serviço ControlPanel..."

curl -so /etc/systemd/system/controlpanel.service "$GITHUB_URL"/configs/controlpanel.service

case "$OS" in
  debian | ubuntu)
    sed -i -e "s@<user>@www-data@g" /etc/systemd/system/controlpanel.service
  ;;
  centos)
    sed -i -e "s@<user>@nginx@g" /etc/systemd/system/controlpanel.service
  ;;
esac

systemctl enable controlpanel.service --now
}

deps_ubuntu() {
print "Instalando dependências para Ubuntu ${OS_VER}"

# Adicionar o comando "add-apt-repository"
apt-get install -y software-properties-common curl apt-transport-https ca-certificates gnupg

# Adicionar repositórios adicionais para PHP, Redis e MariaDB
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

# Atualizar lista de repositórios
apt-get update -y && apt-get upgrade -y

# Adicionar repositório universe se estiver no Ubuntu 18.04
[ "$OS_VER_MAJOR" == "18" ] && apt-add-repository universe

# Instalar Dependências
apt-get install -y php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip,intl} mariadb-server nginx tar unzip git redis-server psmisc net-tools

# Ativar serviços
enable_services_debian_based
}

deps_debian() {
print "Instalando dependências para Debian ${OS_VER}"

# MariaDB precisa do dirmngr
apt-get install -y dirmngr

# Instalar PHP 8.0 usando o repositório do sury
apt-get install -y ca-certificates apt-transport-https lsb-release
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

# Adicionar o repositório MariaDB
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash

# Atualizar lista de repositórios
apt-get update -y && apt-get upgrade -y


# Instalar Dependências
apt-get install -y php8.1 php8.1-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip,intl} mariadb-server nginx tar unzip git redis-server psmisc net-tools

# Ativar serviços
enable_services_debian_based
}

deps_centos() {
print "Instalando dependências para CentOS ${OS_VER}"

if [ "$OS_VER_MAJOR" == "7" ]; then
    # Ferramentas do SELinux
    yum install -y policycoreutils policycoreutils-python selinux-policy selinux-policy-targeted libselinux-utils setroubleshoot-server setools setools-console mcstrans
    
    # Instalar MariaDB
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash

    # Adicionar repositório remi (php8.1)
    yum install -y epel-release http://rpms.remirepo.net/enterprise/remi-release-7.rpm
    yum install -y yum-utils
    yum-config-manager -y --disable remi-php54
    yum-config-manager -y --enable remi-php81

    # Instalar dependências
    yum -y install php php-common php-tokenizer php-curl php-fpm php-cli php-json php-mysqlnd php-mcrypt php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache php-intl mariadb-server nginx curl tar zip unzip git redis psmisc net-tools
    yum update -y
  elif [ "$OS_VER_MAJOR" == "8" ]; then
    # Ferramentas do SELinux
    yum install -y policycoreutils selinux-policy selinux-policy-targeted setroubleshoot-server setools setools-console mcstrans
    
    # Adicionar repositório remi (php8.1)
    yum install -y epel-release http://rpms.remirepo.net/enterprise/remi-release-8.rpm
    yum module enable -y php:remi-8.1

    # Instalar MariaDB
    yum install -y mariadb mariadb-server

    # Instalar dependências
    yum install -y php php-common php-fpm php-cli php-json php-mysqlnd php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache php-intl mariadb-server nginx curl tar zip unzip git redis psmisc net-tools
    yum update -y
fi

# Ativar serviços
enable_services_centos_based

# SELinux
allow_selinux
}

install_controlpanel() {
print "Iniciando a instalação, isso pode levar alguns minutos, por favor, aguarde."
sleep 2

case "$OS" in
  debian | ubuntu)
    apt-get update -y && apt-get upgrade -y

    [ "$OS" == "ubuntu" ] && deps_ubuntu
    [ "$OS" == "debian" ] && deps_debian
  ;;
  centos)
    yum update -y && yum upgrade -y
    deps_centos
  ;;
esac

[ "$OS" == "centos" ] && centos_php
install_composer
download_files
set_permissions
configure_environment
check_database_info
configure_database
configure_firewall
configure_crontab
configure_service
[ "$CONFIGURE_SSL" == true ] && configure_ssl
configure_webserver
bye
}


main() {
# Verificar se já está instalado e verificar a versão #
if [ -d "/var/www/controlpanel" ]; then
  update_variables
  if [ "$CLIENT_VERSION" != "$LATEST_VERSION" ]; then
      print_warning "Você já possui o painel instalado."
      echo -ne "* O script detectou que a versão do seu painel é ${YELLOW}$CLIENT_VERSION${RESET}, a versão mais recente do painel é ${YELLOW}$LATEST_VERSION${RESET}, você gostaria de atualizar? (y/N): "
      read -r UPGRADE_PANEL
      if [[ "$UPGRADE_PANEL" =~ [Yy] ]]; then
          check_distro
          only_upgrade_panel
        else
          print "Ok, até logo..."
          exit 1
      fi
    else
      print_warning "O painel já está instalado, abortando..."
      exit 1
  fi
fi

# Verificar se o Pterodactyl está instalado #
if [ ! -d "/var/www/pterodactyl" ]; then
  print_warning "Não foi encontrada uma instalação do Pterodactyl no diretório $YELLOW/var/www/pterodactyl${RESET}"
  echo -ne "* Seu painel Pterodactyl está instalado nesta máquina? (y/N): "
  read -r PTERO_DIR
  if [[ "$PTERO_DIR" =~ [Yy] ]]; then
    echo -e "* ${GREEN}EXEMPLO${RESET}: /var/www/meuptero"
    echo -ne "* Informe o diretório onde seu painel Pterodactyl está instalado: "
    read -r PTERO_DIR
    if [ -f "$PTERO_DIR/config/app.php" ]; then
        print "Pterodactyl encontrado, continuando..."
      else
        print_error "Pterodactyl não encontrado, executando o script novamente..."
        main
    fi
  fi
fi

# Verificar Distribuição #
check_distro

# Verificar se o SO é compatível #
check_compatibility

# Definir FQDN para o painel #
while [ -z "$FQDN" ]; do
  print_warning "Não use um domínio que já está sendo usado por outra aplicação, como o domínio do seu Pterodactyl."
  echo -ne "* Defina o Nome do Host/FQDN para o painel (${YELLOW}painel.exemplo.com${RESET}): "
  read -r FQDN
  [ -z "$FQDN" ] && print_error "FQDN não pode ficar vazio"
done

# Instalar os pacotes para verificar o FQDN e perguntar sobre SSL somente se o FQDN for uma string #
if [[ "$FQDN" == [a-zA-Z]* ]]; then
  ask_ssl
fi


# Definir o host do banco de dados #
echo -ne "* Informe o host do banco de dados (${YELLOW}127.0.0.1${RESET}): "
read -r DB_HOST
[ -z "$DB_HOST" ] && DB_HOST="127.0.0.1"

# Definir a porta do banco de dados #
echo -ne "* Informe a porta do banco de dados (${YELLOW}3306${RESET}): "
read -r DB_PORT
[ -z "$DB_PORT" ] && DB_PORT="3306"

# Definir o nome do banco de dados #
echo -ne "* Informe o nome do banco de dados (${YELLOW}controlpanel${RESET}): "
read -r DB_NAME
[ -z "$DB_NAME" ] && DB_NAME="controlpanel"

# Definir o usuário do banco de dados #
echo -ne "* Informe o nome de usuário do banco de dados (${YELLOW}controlpaneluser${RESET}): "
read -r DB_USER
[ -z "$DB_USER" ] && DB_USER="controlpaneluser"

# Definir a senha do banco de dados #
password_input DB_PASS "Informe a senha do banco de dados (Pressione Enter para uma senha aleatória): " "A senha não pode ficar vazia!" "$RANDOM_PASSWORD"

# Perguntar sobre o Fuso Horário #
echo -e "* Lista de fusos horários válidos aqui: ${YELLOW}$(hyperlink "http://php.net/manual/en/timezones.php")${RESET}"
echo -ne "* Selecione o Fuso Horário (${YELLOW}America/New_York${RESET}): "
read -r TIMEZONE
[ -z "$TIMEZONE" ] && TIMEZONE="America/New_York"

# Resumo #
echo
print_brake 75
echo
echo -e "* Nome do Host/FQDN: $FQDN"
echo -e "* Hospedagem do Banco de Dados: $DB_HOST"
echo -e "* Porta do Banco de Dados: $DB_PORT"
echo -e "* Nome do Banco de Dados: $DB_NAME"
echo -e "* Usuário do Banco de Dados: $DB_USER"
echo -e "* Senha do Banco de Dados: (censurada)"
echo -e "* Fuso Horário: $TIMEZONE"
echo -e "* Configurar SSL: $CONFIGURE_SSL"
echo
print_brake 75
echo

# Criar o diretório de logs #
mkdir -p $INFORMATIONS

# Escrever as informações em um log #
{
  echo -e "* Nome do Host/FQDN: $FQDN"
  echo -e "* Hospedagem do Banco de Dados: $DB_HOST"
  echo -e "* Porta do Banco de Dados: $DB_PORT"
  echo -e "* Nome do Banco de Dados: $DB_NAME"
  echo -e "* Usuário do Banco de Dados: $DB_USER"
  echo -e "* Senha do Banco de Dados: $DB_PASS"
  echo ""
  echo "* Após usar este arquivo, exclua-o imediatamente!"
} > $INFORMATIONS/install.info

# Confirmar todas as escolhas #
echo -n "* Configurações iniciais concluídas, deseja continuar com a instalação? (y/N): "
read -r CONTINUE_INSTALL
[[ "$CONTINUE_INSTALL" =~ [Yy] ]] && install_controlpanel
[[ "$CONTINUE_INSTALL" == [Nn] ]] && print_error "Instalação abortada!" && exit 1
}

bye() {
echo
print_brake 90
echo
echo -e "${GREEN}* O script concluiu o processo de instalação!${RESET}"

[ "$CONFIGURE_SSL" == true ] && APP_URL="https://$FQDN"
[ "$CONFIGURE_SSL" == false ] && APP_URL="http://$FQDN"

echo -e "${GREEN}* Para completar a configuração do seu painel, vá para ${YELLOW}$(hyperlink "$APP_URL/install")${RESET}"
echo -e "${GREEN}* Obrigado por usar este script!"
print_brake 90
echo
}

# Executar o Script #
main
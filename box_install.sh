#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function to display ASCII header
show_header() {
  clear
  echo "##############################################"
  echo "#                                            #"
  echo "#               3sIT Installer               #"
  echo "#                                            #"
  echo "##############################################"
  echo ""
}

# Function to show progress
show_progress() {
  echo -n "$1"
  for i in $(seq 1 20); do
    echo -n "."
    sleep 0.1
  done
  echo ""
}

# Function to install VPN
install_vpn() {
  # Check if the Netbird setup key is provided
  if [ -z "$1" ]; then
    echo "Usage: $0 <netbird-setup-key>"
    exit 1
  fi

  NETBIRD_SETUP_KEY=$1

  show_progress "Installing Netbird"
  curl -fsSL https://pkgs.netbird.io/install.sh | sudo bash | pv -pte -N "Installing Netbird" > /dev/null

  show_progress "Configuring Netbird"
  sudo netbird up --setup-key $NETBIRD_SETUP_KEY | pv -pte -N "Configuring Netbird" > /dev/null
  sudo systemctl restart netbird
}

# Function to install monitoring proxy
install_monitoring_proxy() {
  DB_ROOT_PASSWORD=''
  ZABBIX_DB_PASSWORD='IRAKisimeimer4'
  ZABBIX_DB_NAME='zabbix_proxy'
  ZABBIX_DB_USER='zabbix'

  # BASE SYSTEM PREP
  show_progress "Updating system"
  apt update -qq && apt upgrade -y -qq | pv -pte -N "Updating system" > /dev/null

  show_progress "Installing base packages"
  apt -y install ssh openssh-server net-tools curl wget git ntp sudo -qq | pv -pte -N "Installing base packages" > /dev/null

  show_progress "Setting timezone"
  timedatectl set-timezone Europe/Bucharest

  # Install MariaDB
  show_progress "Installing MariaDB"
  apt install -y mariadb-server -qq | pv -pte -N "Installing MariaDB" > /dev/null

  show_progress "Starting and securing MariaDB"
  systemctl start mariadb
  systemctl enable mariadb

  # Secure MariaDB installation (assuming root password is not set, you may need to modify this part)
  mysql_secure_installation <<EOF

y
n
y
y
EOF

  # Configure MariaDB for Zabbix
  show_progress "Configuring MariaDB"
  mysql -uroot <<EOF
CREATE DATABASE ${ZABBIX_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER '${ZABBIX_DB_USER}'@'localhost' IDENTIFIED BY '${ZABBIX_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${ZABBIX_DB_NAME}.* TO '${ZABBIX_DB_USER}'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
EOF

  # Install Zabbix repository
  show_progress "Installing Zabbix repository"
  wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian12_all.deb -q
  dpkg -i zabbix-release_7.0-2+debian12_all.deb -q
  apt update -qq

  # Install Zabbix proxy and SQL scripts
  show_progress "Installing Zabbix proxy"
  apt install -y zabbix-proxy-mysql zabbix-sql-scripts -qq | pv -pte -N "Installing Zabbix proxy" > /dev/null

  # Import initial schema and data
  show_progress "Importing initial schema and data"
  cat /usr/share/zabbix-sql-scripts/mysql/proxy.sql | mysql --default-character-set=utf8mb4 -u${ZABBIX_DB_USER} -p${ZABBIX_DB_PASSWORD} ${ZABBIX_DB_NAME}

  # Disable log_bin_trust_function_creators
  show_progress "Disabling log_bin_trust_function_creators"
  mysql -uroot <<EOF
SET GLOBAL log_bin_trust_function_creators = 0;
EOF

  # Configure Zabbix proxy
  show_progress "Configuring Zabbix proxy"
  sed -i "s/^# DBPassword=.*/DBPassword=${ZABBIX_DB_PASSWORD}/" /etc/zabbix/zabbix_proxy.conf

  # Start and enable Zabbix proxy service
  show_progress "Starting Zabbix proxy service"
  systemctl restart zabbix-proxy
  systemctl enable zabbix-proxy

  echo "Zabbix Proxy installation and configuration is complete."
}

# Main menu
show_header
echo "Choose an option to install:"
echo "1. VPN Account"
echo "2. Monitoring Proxy"
echo "3. Both"
echo "4. Exit"
read -p "Enter your choice: " choice

case $choice in
  1)
    read -p "Enter Netbird setup key: " netbird_setup_key
    install_vpn $netbird_setup_key
    ;;
  2)
    install_monitoring_proxy
    ;;
  3)
    read -p "Enter Netbird setup key: " netbird_setup_key
    install_vpn $netbird_setup_key
    install_monitoring_proxy
    ;;
  4)
    echo "Exiting..."
    exit 0
    ;;
  *)
    echo "Invalid choice. Exiting..."
    exit 1
    ;;
esac

echo "Installation complete."

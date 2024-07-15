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
  curl -fsSL https://pkgs.netbird.io/install.sh | sudo bash

  show_progress "Configuring Netbird"
  sudo netbird login --setup-key $NETBIRD_SETUP_KEY --management-url https://netbird.3sit.ro:443
  sudo systemctl restart netbird || echo "Netbird service not found or failed to restart."
}

# Main menu
show_header
echo "Choose an option to install:"
echo "1. VPN Account"
echo "2. Exit"
read -p "Enter your choice: " choice

case $choice in
  1)
    read -p "Enter Netbird setup key: " netbird_setup_key
    install_vpn $netbird_setup_key
    ;;
  2)
    echo "Exiting..."
    exit 0
    ;;
  *)
    echo "Invalid choice. Exiting..."
    exit 1
    ;;
esac

echo "Installation complete."

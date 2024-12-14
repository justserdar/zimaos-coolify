#!/usr/bin/env bash

# Set strict error handling
set -euo pipefail

# Set text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Function to print header
print_header() {
    echo "================================================"
    echo "$1"
    echo "================================================"
    echo
}

# Install and configure SSH
install_configure_ssh() {
    # Ensure SSH server is installed (handled manually for ZimaOS)
    echo "Ensuring SSH server is installed..."
    if ! command -v sshd &>/dev/null; then
        echo -e "${RED}SSHD not found. Please install OpenSSH server manually.${NC}"
        exit 1
    fi

    echo "Configuring SSH..."

    # Backup original SSH configuration
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

    # Update SSH configuration for persistent key authentication
    sed -i "s|^#*AuthorizedKeysFile.*|AuthorizedKeysFile /DATA/.ssh/authorized_keys|" /etc/ssh/sshd_config
    sed -i "s|^#*PubkeyAuthentication.*|PubkeyAuthentication yes|" /etc/ssh/sshd_config

    # Ask user for PermitRootLogin preference
    echo "Select PermitRootLogin setting:"
    echo "1) yes            - Allows root login with password and key-based authentication"
    echo "2) without-password - Allows root login with key-based authentication only"
    echo "3) prohibit-password - Same as without-password (recommended for security)"
    read -p "Enter choice (1-3): " root_login_choice

    case $root_login_choice in
        1) root_login="yes";;
        2) root_login="without-password";;
        3) root_login="prohibit-password";;
        *) root_login="prohibit-password";;
    esac

    sed -i "s/^#*PermitRootLogin.*/PermitRootLogin ${root_login}/" /etc/ssh/sshd_config

    # Create a writable directory for SSH keys
    mkdir -p /DATA/.ssh
    chmod 700 /DATA/.ssh

    # Mount the writable directory to ~/.ssh (if necessary)
    # ^ this will reset on reboots since it is not persistent
    if [ ! -d ~/.ssh ] || [ "$(mountpoint -q ~/.ssh && echo mounted)" != "mounted" ]; then
        echo "Mounting writable SSH directory to ~/.ssh..."
        mkdir -p ~/.ssh
        mount --bind /DATA/.ssh ~/.ssh
    fi

    # Add public key to authorized_keys
    # ^ this doesnt work on ZimaOS: 'Read-only file system'
    echo "Adding your public key to authorized_keys..."
    read -p "Enter your public SSH key: " ssh_key
    echo "$ssh_key" >> /DATA/.ssh/authorized_keys
    chmod 600 /DATA/.ssh/authorized_keys

    # Restart SSH service
    # ^ this doesnt work on ZimaOS: 'Extra argument "restart" in sshd command'
    echo "Restarting SSH service..."
    /usr/sbin/sshd -t && /usr/sbin/sshd restart
    echo -e "${GREEN}SSH configured successfully!${NC}"
}

clear_cache() {
    echo "Clearing Coolify cache..."
    docker exec -it zimaos-coolify php artisan optimize
    echo -e "${GREEN}Cache cleared successfully!${NC}"
}

menu() {
    # Main menu
    clear
    print_header "ZimaOS Coolify Setup V0.0.1"

    echo "Here are some links:"
    echo "https://community.bigbeartechworld.com"
    echo "https://github.com/BigBearTechWorld"
    echo ""
    echo "If you would like to support me, please consider buying me a tea:"
    echo "https://ko-fi.com/bigbeartechworld"
    echo ""
    echo "===================="
    echo "Please select an option:"
    echo "1) Setup SSH and configurations"
    echo "2) Clear cache"
    read -p "Enter choice (1-2): " menu_choice

    case $menu_choice in
        1) install_configure_ssh;;
        2) clear_cache;;
        *) echo "Invalid option selected. Exiting.";;
    esac
}

# Run the menu
menu

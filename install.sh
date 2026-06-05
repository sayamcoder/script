#!/bin/bash

# Color codes for clean output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Custom Intro Banner for Sayam's YouTube Channel
clear
echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}               SAYAM'S INSTALLER              ${NC}"
echo -e "${GREEN}         Airlink Panel Auto Installer         ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this script as root (use sudo).${NC}"
  exit 1
fi

show_menu() {
    echo -e "${YELLOW}Please select an option:${NC}"
    echo "1) Install Airlink Panel"
    echo "2) Run Panel in Background (PM2)"
    echo "3) Exit"
    echo -n "Enter option [1-3]: "
}

install_panel() {
    echo -e "\n${BLUE}[1/6] Preparing directory and cloning repository...${NC}"
    mkdir -p /var/www
    cd /var/www || exit

    # Handle existing directory to avoid conflicts
    if [ -d "panel" ]; then
        echo -e "${YELLOW}Warning: /var/www/panel already exists.${NC}"
        read -p "Do you want to backup and overwrite it? (y/n): " confirm
        if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
            mv panel "panel_backup_$(date +%F_%T)"
            echo -e "${GREEN}Existing panel directory backed up.${NC}"
        else
            echo -e "${RED}Installation cancelled to protect existing folder.${NC}"
            return
        fi
    fi

    git clone https://github.com/AirlinkLabs/panel.git
    cd panel || exit

    echo -e "\n${BLUE}[2/6] Setting permissions...${NC}"
    chown -R www-data:www-data /var/www/panel
    chmod -R 755 /var/www/panel

    echo -e "\n${BLUE}[3/6] Installing dependencies with pnpm...${NC}"
    # Automatically install pnpm globally if it is missing
    if ! command -v pnpm &> /dev/null; then
        echo -e "${YELLOW}pnpm not found. Installing pnpm globally...${NC}"
        npm install -g pnpm
    fi
    pnpm install

    echo -e "\n${BLUE}[4/6] Setting up environment configuration...${NC}"
    if [ ! -f .env ]; then
        cp example.env .env
        echo -e "${GREEN}Copied example.env to .env${NC}"
    else
        echo -e "${YELLOW}.env file already exists. Skipping copy step.${NC}"
    fi

    echo -e "${YELLOW}You must configure your .env file now.${NC}"
    echo -e "Make sure to set PORT, URL, SESSION_SECRET, and DATABASE_URL."
    read -p "Press Enter to open .env in nano editor..."
    nano .env

    echo -e "\n${BLUE}[5/6] Running database migrations...${NC}"
    pnpm run migrate:deploy

    echo -e "\n${BLUE}[6/6] Compiling TypeScript and building CSS...${NC}"
    pnpm run build

    echo -e "\n${GREEN}Airlink Panel installation has finished!${NC}"
    echo -e "You can now choose Option 2 from the main menu to run it in the background."
}

run_background() {
    echo -e "\n${BLUE}Setting up PM2 to run Airlink Panel in the background...${NC}"
    
    # Check if npm/node is installed
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}Error: npm is not installed. Please install Node.js first.${NC}"
        return
    fi

    echo -e "${BLUE}Installing PM2 globally...${NC}"
    npm install -g pm2

    if [ -d "/var/www/panel" ]; then
        cd /var/www/panel || exit
        
        echo -e "${BLUE}Starting Airlink Panel using PM2...${NC}"
        pm2 start "pnpm run start" --name airlink-panel
        
        echo -e "${BLUE}Saving PM2 process configuration and setting up system startup...${NC}"
        pm2 save
        pm2 startup
        
        echo -e "\n${GREEN}Airlink Panel is now active in the background!${NC}"
        echo -e "To view panel status, run: ${YELLOW}pm2 status${NC}"
        echo -e "To view logs, run: ${YELLOW}pm2 logs airlink-panel${NC}"
    else
        echo -e "${RED}Error: /var/www/panel directory not found. Please install the panel first (Option 1).${NC}"
    fi
}

# Main script loop
while true; do
    show_menu
    read opt
    case $opt in
        1)
            install_panel
            ;;
        2)
            run_background
            ;;
        3)
            echo -e "${BLUE}Thank you for using Sayam's Installer. Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection. Please try again.${NC}"
            ;;
    esac
    echo ""
done

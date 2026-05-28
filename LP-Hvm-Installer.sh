#!/bin/bash

# ==========================================
# COLOR DEFINITIONS (ANSI Escape Codes)
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (Reset)

# ==========================================
# OS DETECTION & VALIDATION
# ==========================================
clear
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}❌ Cannot detect operating system. Exiting...${NC}"
    exit 1
fi

if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    echo -e "${RED}❌ Unsupported OS: $OS${NC}"
    echo -e "${YELLOW}This installer supports Ubuntu and Debian only.${NC}"
    exit 1
fi

echo -e "${GREEN}Detected OS:${NC} ${YELLOW}$OS${NC}"
sleep 1.5

# ==========================================
# MAIN INTERACTIVE LOOP
# ==========================================
while true; do
    clear
    # Colorful Box-Drawn Interface Block
    echo -e "${CYAN}╔═════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${YELLOW}⚡ HVM INSTALLER ⚡${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}╠═════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}1.${NC} HVM 5.1 Installer               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}2.${NC} LXC / LXD Installer             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}3.${NC} Cloudflare Setup                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}4.${NC} LXC BOT V6                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${RED}0.${NC} Exit / Close Menu               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚═════════════════════════════════════╝${NC}"
    echo ""

    read -p "Enter choice [0-4]: " choice

    case $choice in
        1)
            echo -e "\n${BLUE}Executing Option 1: HVM 5.1 Installer...${NC}"
            apt update -y && apt install git python3-pip -y

            # Setup global pip override for managed environments
            mkdir -p ~/.config/pip
            echo -e "[global]\nbreak-system-packages = true" > ~/.config/pip/pip.conf

            # Pull source tools directly to fixed runtime destinations
            rm -rf /root/hvm
            if git clone https://github.com/DreamHost2ws/HVM5.1 /root/hvm; then
                cd /root/hvm || exit
                pip install -r requirements.txt

                # Generate matching Systemd Application Service Units
                cat <<EOF > /etc/systemd/system/hvm.service
[Unit]
Description=HVM Panel (Discord Bot)
After=network.target

[Service]
User=root
WorkingDirectory=/root/hvm
ExecStart=/usr/bin/python3 /root/hvm/hvm-5.1.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

                systemctl daemon-reload
                systemctl enable hvm
                systemctl restart hvm
                echo -e "${GREEN}✓ HVM Daemon successfully registered and started!${NC}"
            else
                echo -e "${RED}❌ Git repository cloning failed.${NC}"
            fi
            
            echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
            read -r
            ;;

        2)
            echo -e "\n${BLUE}Executing Option 2: LXC / LXD Installer...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/hopingboyz/lxc-installer/main/lxc-installer.sh)
            
            echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
            read -r
            ;;

        3)
            echo -e "\n${BLUE}Executing Option 3: Cloudflare Setup...${NC}"
            sudo mkdir -p --mode=0755 /usr/share/keyrings
            
            curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
            echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
            
            sudo apt-get update && sudo apt-get install cloudflared -y
            
            read -p "Enter your Cloudflare Tunnel Token: " token
            if [ -n "$token" ]; then
                cloudflared service install "$token"
                echo -e "${GREEN}✓ Cloudflare service configuration deployed!${NC}"
            else
                echo -e "${RED}❌ Token cannot be blank.${NC}"
            fi

            echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
            read -r
            ;;

        4)
            echo -e "\n${BLUE}Executing Option 4: LXC BOT V6...${NC}"
            apt update && apt install git python3-pip -y

            mkdir -p ~/.config/pip
            echo -e "[global]\nbreak-system-packages = true" > ~/.config/pip/pip.conf

            # Clean and target installation paths safely
            rm -rf /root/VPSbotv6
            if ! git clone https://github.com/DreamHost2ws/VPSbotv6 /root/VPSbotv6; then
                echo -e "${RED}❌ Failed to clone tool components.${NC}"
                echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
                read -r
                continue
            fi

            # Operating System Provisioning Logic
            if [[ "$OS" == "ubuntu" ]]; then
                sudo apt update && sudo apt upgrade -y
                sudo apt install lxc lxc-utils bridge-utils uidmap snapd -y
                sudo systemctl enable --now snapd.socket
                sudo snap install lxd
                # System group bypass to avoid script execution halting
                sg lxd -c "lxd init --auto"
            fi

            if [[ "$OS" == "debian" ]]; then
                sudo apt install snapd bridge-utils uidmap -y
                sudo systemctl enable --now snapd.socket
                [ -L /snap ] || sudo ln -s /var/lib/snapd/snap /snap
                sudo snap install lxd
                sg lxd -c "lxd init --auto"
            fi

            cd /root/VPSbotv6 || exit
            if [ -f requirements.txt ]; then
                pip install -r requirements.txt
            fi

            read -p "Enter DISCORD BOT TOKEN: " TOKEN
            read -p "Enter MAIN ADMIN ID: " ADMIN

            # Deploy Service Management Engine Components
            cat <<EOF > /etc/systemd/system/unixbot.service
[Unit]
Description=UnixBot Discord Bot
After=network.target

[Service]
User=root
WorkingDirectory=/root/VPSbotv6
Environment="PYTHONUNBUFFERED=1"
Environment="DISCORD_TOKEN=$TOKEN"
Environment="MAIN_ADMIN_ID=$ADMIN"
ExecStart=/usr/bin/python3 /root/VPSbotv6/bot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload
            systemctl enable unixbot
            systemctl restart unixbot

            echo -e "${GREEN}✓ LXC BOT V6 Installed & Managed via background systemd service systems.${NC}"
            echo -e "\n${YELLOW}Press Enter to return to menu...${NC}"
            read -r
            ;;

        0)
            echo -e "\n${BLUE}Exiting Installer System... Goodbye.${NC}"
            break
            ;;

        *)
            echo -e "\n${RED}Invalid option! Please pick an option between 0 and 4.${NC}"
            sleep 1
            ;;
    esac
done

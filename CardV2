#!/bin/bash

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
blue='\033[0;34m'
rest='\033[0m'

# If running in Termux, update and upgrade
if [ -d "$HOME/.termux" ] && [ -z "$(command -v jq)" ]; then
    echo "Running update & upgrade ..."
    pkg update -y
    pkg upgrade -y
fi

# Function to install necessary packages
install_packages() {
    local packages=(curl jq bc)
    local missing_packages=()

    # Check for missing packages
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    # If any package is missing, install missing packages
    if [ ${#missing_packages[@]} -gt 0 ]; then
        if [ -n "$(command -v pkg)" ]; then
            pkg install "${missing_packages[@]}" -y
        elif [ -n "$(command -v apt)" ]; then
            sudo apt update -y
            sudo apt install "${missing_packages[@]}" -y
        elif [ -n "$(command -v yum)" ]; then
            sudo yum update -y
            sudo yum install "${missing_packages[@]}" -y
        elif [ -n "$(command -v dnf)" ]; then
            sudo dnf update -y
            sudo dnf install "${missing_packages[@]}" -y
        else
            echo -e "${yellow}Unsupported package manager. Please install required packages manually.${rest}"
        fi
    fi
}

# Install the necessary packages
install_packages

# Clear the screen
clear

# Prompt for Authorization
echo -e "${purple}=======${yellow}Hamster Combat Auto Buy Upgrade Card${purple}=======${rest}"
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# Prompt for minimum balance threshold
echo -en "${green}Enter minimum balance threshold (${yellow}the script will stop purchasing if the balance is below this amount${green}):${rest} "
read -r min_balance_threshold
echo -e "${purple}============================${rest}"

# Prompt for card ID to upgrade
echo -en "${green}Enter the ID of the card you want to upgrade:${rest} "
read -r card_id

# Function to purchase upgrade
purchase_upgrade() {
    upgrade_id="$1"
    timestamp=$(date +%s%3N)
    response=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: $Authorization" \
      -H "Origin: https://hamsterkombat.io" \
      -H "Referer: https://hamsterkombat.io/" \
      -d "{\"upgradeId\": \"$upgrade_id\", \"timestamp\": $timestamp}" \
      https://api.hamsterkombatgame.io/clicker/buy-upgrade)
    echo "$response"
}

# Function to get the current balance
get_current_balance() {
    curl -s -X POST \
        -H "Authorization: $Authorization" \
        -H "Origin: https://hamsterkombat.io" \
        -H "Referer: https://hamsterkombat.io/" \
        https://api.hamsterkombatgame.io/clicker/sync | jq -r '.clickerUser.balanceCoins'
}

# Main script logic
main() {
    while true; do
        # Get current balance
        current_balance=$(get_current_balance)

        # Check if current balance is above the threshold
        if (( $(echo "$current_balance > $min_balance_threshold" | bc -l) )); then
            echo -e "${green}Attempting to purchase upgrade for card ID '${yellow}$card_id${green}'...${rest}"

            purchase_status=$(purchase_upgrade "$card_id")

            if echo "$purchase_status" | grep -q "error_code"; then
                echo -e "${red}Purchase failed. Error details: ${cyan}$purchase_status${rest}"
                break
            else
                purchase_time=$(date +"%Y-%m-%d %H:%M:%S")
                price=$(echo "$purchase_status" | jq -r '.price')
                profit=$(echo "$purchase_status" | jq -r '.profitPerHourDelta')

                total_spent=$(echo "$total_spent + $price" | bc)
                total_profit=$(echo "$total_profit + $profit" | bc)
                current_balance=$(echo "$current_balance - $price" | bc)

                echo -e "${green}Upgrade for card ID ${yellow}'$card_id'${green} purchased successfully at ${cyan}$purchase_time${green}.${rest}"
                echo -e "${green}Total spent so far: ${cyan}$total_spent${green} coins.${rest}"
                echo -e "${green}Total profit added: ${cyan}$total_profit${green} coins per hour.${rest}"
                echo -e "${green}Current balance: ${cyan}$current_balance${green} coins.${rest}"
                
                sleep_duration=$((RANDOM % 8 + 5))
                echo -e "${green}Waiting for ${yellow}$sleep_duration${green} seconds before next purchase...${rest}"
                while [ $sleep_duration -gt 0 ]; do
                    echo -ne "${cyan}$sleep_duration\033[0K\r${rest}"
                    sleep 1
                    ((sleep_duration--))
                done
            fi
        else
            echo -e "${red}Current balance ${cyan}(${current_balance}) ${red}is below the threshold ${cyan}(${min_balance_threshold})${red}. Stopping purchases.${rest}"
            break
        fi
    done
}

# Execute the main function
main

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
            exit 1
        fi
    fi
}

# Install the necessary packages
install_packages

# Clear the screen
clear
echo -e "${purple}=======${yellow} Hamster Combat Auto Clicker${purple}=======${rest}"
# Prompt for Authorization
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# Prompt for coin capacity threshold
echo -en "${green}Enter Coin Capacity [${yellow}default:5000${green}]:${rest} "
read -r capacity
capacity=${capacity:-5000}

while true; do
    attempt=0
    success=false

    # Try up to 3 times to get the number of available taps
    while [ $attempt -lt 3 ]; do
        Taps=$(curl -s -X POST \
            https://api.hamsterkombatgame.io/clicker/sync \
            -H "Content-Type: application/json" \
            -H "Authorization: $Authorization" \
            -d '{}' | jq -r '.clickerUser.availableTaps')

        # Check if Taps is a valid integer
        if [[ $Taps =~ ^[0-9]+$ ]]; then
            success=true
            break
        else
            echo -e "${red}Error retrieving taps, retrying... (${attempt}/3)${rest}"
            attempt=$((attempt + 1))
            sleep 5  # Wait for 5 seconds before retrying
        fi
    done

    # If after 3 attempts, we still have an error, go to sleep
    if [ "$success" = false ]; then
        echo -e "${red}Failed to retrieve taps after 3 attempts. Sleeping for the next interval.${rest}"
        random_sleep=$(shuf -i 2400-7200 -n 1)
        echo "Sleeping for $(($random_sleep / 60)) minutes before the next check..."
        sleep "$random_sleep"
        continue
    fi

    # If taps were retrieved successfully, continue with the logic to consume taps
    while [ "$Taps" -ge 30 ]; do
        # Perform the tap action until taps are less than 30
        curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
            -H "Content-Type: application/json" \
            -H "Authorization: $Authorization" \
            -d '{
                "availableTaps": '"$Taps"',
                "count": 3,
                "timestamp": '"$(date +%s)"'
            }' > /dev/null

        echo "Taps left: $Taps"

        # Re-check the number of available taps
        Taps=$(curl -s -X POST \
            https://api.hamsterkombatgame.io/clicker/sync \
            -H "Content-Type: application/json" \
            -H "Authorization: $Authorization" \
            -d '{}' | jq -r '.clickerUser.availableTaps')

        # Handle the case where the retrieved Taps value is not valid
        if [[ ! $Taps =~ ^[0-9]+$ ]]; then
            echo -e "${red}Error retrieving taps during consumption. Breaking out...${rest}"
            break
        fi

        sleep 1
    done

    # Sleep for a random time between 40 minutes and 2 hours
    random_sleep=$(shuf -i 2400-7200 -n 1)
    echo "Sleeping for $(($random_sleep / 60)) minutes before the next check..."
    sleep "$random_sleep"
done

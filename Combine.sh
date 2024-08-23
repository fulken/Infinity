#!/bin/bash

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
rest='\033[0m'

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

# Install necessary packages
install_packages

# Clear the screen
clear
echo -e "${purple}=======${yellow} Hamster Combat Auto Clicker with Cipher Check${purple}=======${rest}"

# Prompt for Authorization
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# Function to check if the current time is within the specified window (22:30 - 00:00)
is_time_within_window() {
    current_time=$(date +%H:%M)
    if [[ "$current_time" > "22:30" ]] || [[ "$current_time" < "00:00" ]]; then
        return 0  # True
    else
        return 1  # False
    fi
}

# Function to fetch available taps
get_available_taps() {
    curl -s -X POST https://api.hamsterkombatgame.io/clicker/sync \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -d '{}' | jq -r '.clickerUser.availableTaps'
}

# Function to check if the cipher has been claimed
check_cipher_claim_status() {
    response=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/config \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -d '{}')

    echo "$response" | jq -r '.dailyCipher.isClaimed'
}

# Main loop
while true; do
    if is_time_within_window; then
        is_claimed=$(check_cipher_claim_status)
        if [ "$is_claimed" = "false" ]; then
            echo -e "${cyan}Daily cipher is not claimed. Checking and claiming...${rest}"

            # Fetch and decode the cipher
            cipher=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/config \
                -H "Accept: application/json" \
                -H "Authorization: $Authorization" \
                -H "Content-Type: application/json" \
                -d '{}' | jq -r '.dailyCipher.cipher')

            if [ -z "$cipher" ]; then
                echo -e "${red}Error: No cipher received.${rest}"
            else
                modified_cipher="${cipher:0:3}${cipher:4}"
                decoded_cipher=$(echo "$modified_cipher" | base64 --decode)

                # Try to claim the cipher
                response=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/claim-daily-cipher \
                    -H "Authorization: $Authorization" \
                    -H "Content-Type: application/json" \
                    -d "{\"cipher\": \"$decoded_cipher\"}")

                if [ "$(echo "$response" | jq -r '.dailyCipher.isClaimed')" == "true" ]; then
                    echo -e "${green}Daily cipher successfully claimed.${rest}"
                else
                    echo -e "${red}Failed to claim the daily cipher.${rest}"
                fi
            fi
        else
            echo -e "${green}Daily cipher is already claimed.${rest}"
        fi
    fi

    # Auto-clicking logic after checking the cipher
    available_taps=$(get_available_taps)
    if [ -z "$available_taps" ] || [ "$available_taps" -lt 0 ]; then
        echo "Failed to retrieve Taps. Exiting script."
        exit 1
    fi

    if [ "$available_taps" -lt 30 ]; then
        echo "Taps are less than 30. Disconnecting and waiting..."

        # Calculate sleep time based on a fixed range
        sleep_time=$(generate_gaussian_delay 2400 600)
        sleep_time=$(awk "BEGIN {print ($sleep_time < 1200) ? 1200 : ($sleep_time > 3600) ? 3600 : $sleep_time}")
        echo "Reconnecting in $(echo "$sleep_time / 60" | bc) minutes..."
        sleep "$sleep_time"
        continue
    fi

    # Tap action
    tap_count=$(shuf -i 10-20 -n 1)
    curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -d '{
            "availableTaps": '"$available_taps"',
            "count": '"$tap_count"', 
            "timestamp": '"$(date +%s)"'
        }' > /dev/null

    echo "Taps left: $available_taps"
    sleep $(generate_gaussian_delay 2 1)
done

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
echo -e "${purple}=======${yellow}Hamster Combat Auto Buy best cards${purple}=======${rest}"
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# Prompt for User-Agent
echo -en "${green}Enter User-Agent [Example: Mozilla/5.0 ...]: ${rest}"
read -r user_agent

# Prompt for minimum balance threshold
echo -en "${green}Enter minimum balance threshold (${yellow}the script will stop purchasing if the balance is below this amount${green}): ${rest}"
read -r min_balance_threshold
echo -e "${purple}============================${rest}"

# Prompt for second card threshold
echo -en "${green}Enter the Threshold that you want to buy a new card? (${yellow}number below 1 to always buy the best card and greater than 1 to buying the second best card threshold${green}): ${rest}"
read -r threshold

# Variables to keep track of total spent and total profit
total_spent=0
total_profit=0

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

# Function to get the best upgrade item
get_best_item() {
    curl -s -X POST -H "User-Agent: $user_agent" \
        -H "Accept: */*" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Referer: https://hamsterkombat.io/" \
        -H "Authorization: $Authorization" \
        -H "Origin: https://hamsterkombat.io" \
        -H "Connection: keep-alive" \
        -H "Sec-Fetch-Dest: empty" \
        -H "Sec-Fetch-Mode: cors" \
        -H "Sec-Fetch-Site: same-site" \
        -H "Priority: u=4" \
        https://api.hamsterkombatgame.io/clicker/upgrades-for-buy | jq -r '.upgradesForBuy | map(select(.isExpired == false and .isAvailable)) | map(select(.profitPerHourDelta != 0 and .price != 0)) | sort_by(-(.profitPerHourDelta / .price))[:1] | .[0] | {id: .id, section: .section, price: .price, profitPerHourDelta: .profitPerHourDelta, cooldownSeconds: .cooldownSeconds}'
}

# Function to get the second best upgrade item
get_second_best_item() {
    curl -s -X POST -H "User-Agent: $user_agent" \
        -H "Accept: */*" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Referer: https://hamsterkombat.io/" \
        -H "Authorization: $Authorization" \
        -H "Origin: https://hamsterkombat.io" \
        -H "Connection: keep-alive" \
        -H "Sec-Fetch-Dest: empty" \
        -H "Sec-Fetch-Mode: cors" \
        -H "Sec-Fetch-Site: same-site" \
        -H "Priority: u=4" \
        https://api.hamsterkombatgame.io/clicker/upgrades-for-buy | jq -r '.upgradesForBuy | map(select(.isExpired == false and .isAvailable)) | map(select(.profitPerHourDelta!= 0 and .price!= 0)) | sort_by(-(.profitPerHourDelta /.price))[:2] |.[1] | {id:.id, section:.section, price:.price, profitPerHourDelta:.profitPerHourDelta, cooldownSeconds:.cooldownSeconds}'
}

# Function to wait for cooldown period with countdown in seconds
wait_for_cooldown() {
    cooldown_seconds="$1"
    start_time=$(date +%s)
    end_time=$((start_time + cooldown_seconds))
    
    echo -e "${yellow}Upgrade is on cooldown. Waiting for cooldown period of ${cyan}$cooldown_seconds${yellow} seconds...${rest}"
    while [ $start_time -lt $end_time ]; do
        current_time=$(date +%s)
        remaining_seconds=$((end_time - current_time))
        echo -ne "${cyan}Remaining: $remaining_seconds sec\033[0K\r"
        sleep 1
        start_time=$current_time
    done
    
    next_start_time=$(date -d @$end_time +"%Y-%m-%d %H:%M:%S")
    echo -e "${green}Cooldown completed. Next purchase attempt will start at ${cyan}$next_start_time${green}.${rest}"
}

# Function to choose between two sets of values
choose() {
    local best_item_id=$1
    local section=$2 
    local price=$3 
    local profit=$4 
    local cooldown=$5 
    local next_item_id=$6 
    local next_item_section=$7 
    local next_item_price=$8 
    local next_item_profit=$9 
    local next_item_cooldown=$10

    # Calculate the ratios
    left_side=$(echo "($threshold) * ($price/$profit)" | bc -l) # Assuming best_price and best_profit are meant to be price and profit
    right_side=$(echo "$next_item_price/$next_item_profit" | bc -l) # Assuming next_price and next_item_profit are meant to be next_item_price and next_item_profit

    if [[ -z "$cooldown" || "$cooldown" -eq 0 ]]; then
        echo "$best_item_id"
    elif [[ -v next_item_cooldown && -n "$next_item_cooldown" && "$next_item_cooldown" -ne 0 ]]; then
        echo "$best_item_id"
    elif (( $(echo "$left_side > $right_side" | bc -l) )); then
        echo "$next_item_id"
    else
        echo "$best_item_id"
    fi
}

# Main script logic
main() {
    while true; do
        # Get the best item to buy
        best_item=$(get_best_item)
        best_item_id=$(echo "$best_item" | jq -r '.id')
        section=$(echo "$best_item" | jq -r '.section')
        price=$(echo "$best_item" | jq -r '.price')
        profit=$(echo "$best_item" | jq -r '.profitPerHourDelta')
        cooldown=$(echo "$best_item" | jq -r '.cooldownSeconds')
        echo -e "${blue}The best item to buy:${yellow} $best_item_id${rest}"

        # Get the second item
        second_item=$(get_second_best_item)
        
        next_item_id=$(echo "$second_item" | jq -r '.id')
        next_item_section=$(echo "$second_item" | jq -r '.section')
        next_item_price=$(echo "$second_item" | jq -r '.price')
        next_item_profit=$(echo "$second_item" | jq -r '.profitPerHourDelta')
        next_item_cooldown=$(echo "$second_item" | jq -r '.cooldownSeconds')

        # Choose the item to buy
        item_to_buy=$(choose "$best_item_id" "$section" "$price" "$profit" "$cooldown" "$next_item_id" "$next_item_section" "$next_item_price" "$next_item_profit" "$next_item_cooldown")

        if [[ "$item_to_buy" == "$best_item_id" ]]; then
            echo -e "${green}Buying best item: $best_item_id${rest}"
            purchase_response=$(purchase_upgrade "$best_item_id")
            # Handle the purchase response and update totals
        elif [[ "$item_to_buy" == "$next_item_id" ]]; then
            echo -e "${green}Buying second best item: $next_item_id${rest}"
            purchase_response=$(purchase_upgrade "$next_item_id")
            # Handle the purchase response and update totals
        fi

        # Wait for cooldown if needed
        if [ -n "$cooldown" ] && [ "$cooldown" -ne 0 ]; then
            wait_for_cooldown "$cooldown"
        fi

        # Sleep before the next iteration
        sleep 5
    done
}

# Run the main function
main

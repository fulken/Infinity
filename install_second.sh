#!/bin/bash

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
blue='\033[0;34m'
rest='\033[0m'

# Install necessary packages (if needed)
install_packages() {
    local packages=(curl jq bc)
    local missing_packages=()

    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done

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

install_packages

# Clear the screen
clear

# Prompt for Authorization and other inputs
echo -e "${purple}=======${yellow}Hamster Combat Auto Buy best cards${purple}=======${rest}"
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"
echo -en "${green}Enter minimum balance threshold (${yellow}the script will stop purchasing if the balance is below this amount${green}):${rest} "
read -r min_balance_threshold
echo -e "${purple}============================${rest}"
echo -en "${green}Enter the Threshold that you want to buy a new card? (${yellow}number below 1 to always buy the best card and greater then 1 to buying the second best card threshold${green}):${rest}"
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
    curl -s -X POST -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
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

get_second_best_item() {
    curl -s -X POST -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
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
        https://api.hamsterkombatgame.io/clicker/upgrades-for-buy | jq -r '.upgradesForBuy | map(select(.isExpired == false and.isAvailable)) | map(select(.profitPerHourDelta!= 0 and.price!= 0)) | sort_by(-(.profitPerHourDelta /.price))[:2] |.[1] | {id:.id, section:.section, price:.price, profitPerHourDelta:.profitPerHourDelta, cooldownSeconds:.cooldownSeconds}'
}

# Function to wait for cooldown period with countdown
wait_for_cooldown() {
    cooldown_seconds="$1"
    echo -e "${yellow}Upgrade is on cooldown. Waiting for cooldown period of ${cyan}$cooldown_seconds${yellow} seconds...${rest}"
    while [ $cooldown_seconds -gt 0 ]; do
        echo -ne "${cyan}$cooldown_seconds\033[0K\r"
        sleep 1
        ((cooldown_seconds--))
    done
}

# Function to choose between two sets of values
choose_card_to_upgrade() {
    local best_item_id=$1
    local section=$2 
    local price=$3 
    local profit=$4 
    local cooldown=$5 
    local next_item_id=$6 
    local next_item_section=$7 
    local next_item_price=$8 
    local next_item_profit=$9 
    local next_item_cooldown=${10}

    # Calculate the ratios
    left_side=$(echo "($threshold) * ($price/$profit)" | bc -l)
    right_side=$(echo "$next_item_price/$next_item_profit" | bc -l)

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
        best_item=$(get_best_item)
        best_item_id=$(echo "$best_item" | jq -r '.id')
        section=$(echo "$best_item" | jq -r '.section')
        price=$(echo "$best_item" | jq -r '.price')
        profit=$(echo "$best_item" | jq -r '.profitPerHourDelta')
        cooldown=$(echo "$best_item" | jq -r '.cooldownSeconds')
        echo -e "${blue}The best item to buy:${yellow} $best_item_id${rest}"

        second_item=$(get_second_best_item)
        next_item_id=$(echo "$second_item" | jq -r '.id')
        next_item_section=$(echo "$second_item" | jq -r '.section')
        next_item_price=$(echo "$second_item" | jq -r '.price')
        next_item_profit=$(echo "$second_item" | jq -r '.profitPerHourDelta')
        next_item_cooldown=$(echo "$second_item" | jq -r '.cooldownSeconds')
        echo -e "${blue}The Second best item to buy:${yellow} $next_item_id${rest}"

        # انتخاب بهترین کارت بر اساس کول‌دان
        selected_item_id=$(choose_card_to_upgrade "$best_item_id" "$section" "$price" "$profit" "$cooldown" "$next_item_id" "$next_item_section" "$next_item_price" "$next_item_profit" "$next_item_cooldown")
        echo -e "${blue}Best card selected with id:${yellow} $selected_item_id${rest}"

        current_balance=$(curl -s -X POST -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
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
            https://api.hamsterkombatgame.io/clicker/get-profile | jq -r '.hamster.token')

        if (( $(echo "$current_balance < $price" | bc -l) )); then
            echo -e "${red}Not enough balance to purchase the card. Stopping script.${rest}"
            break
        fi

        if (( $(echo "$current_balance < $min_balance_threshold" | bc -l) )); then
            echo -e "${red}Current balance is below the minimum balance threshold. Stopping script.${rest}"
            break
        fi

        if [[ "$selected_item_id" == "$best_item_id" ]]; then
            # اگر کارت انتخاب شده همان بهترین کارت است اما در کول‌دان باشد
            if [[ "$cooldown" -ne 0 ]]; then
                wait_for_cooldown "$cooldown"
            fi
        elif [[ "$selected_item_id" == "$next_item_id" && "$next_item_cooldown" -ne 0 ]]; then
            # اگر کارت انتخاب شده دومین کارت بهترین است اما در کول‌دان باشد
            wait_for_cooldown "$next_item_cooldown"
        fi

        response=$(purchase_upgrade "$selected_item_id")
        echo -e "${green}Purchase response:${rest} $response"
        echo ""

        echo -e "${yellow}Waiting 10 seconds before the next check...${rest}"
        sleep 10
    done
}

main

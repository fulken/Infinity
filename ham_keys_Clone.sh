#!/bin/bash

# Colors
yellow='\033[0;33m'
purple='\033[0;35m'
green='\033[0;32m'
rest='\033[0m'

# Check dependencies and install if necessary
install_dependencies() {
    if ! command -v jq &> /dev/null; then
        if [ -n "$TERMUX_VERSION" ]; then
            pkg update -y
            pkg install -y jq
        else
            apt update -y && apt install -y jq
        fi
    fi

    if ! command -v uuidgen &> /dev/null; then
        if [ -n "$TERMUX_VERSION" ]; then
            pkg install uuid-utils -y
        else
            apt update -y && apt install uuid-runtime -y
        fi
    fi
}

# Load proxies from file if available
load_proxies() {
    if [[ -f "$PROXY_FILE" ]]; then
        mapfile -t proxies < "$PROXY_FILE"
    else
        echo -e "${yellow}Proxy file not found. Continuing without proxy.${rest}"
        proxies=()
    fi
}

# Generate client ID
generate_client_id() {
    echo "$(date +%s%3N)-$(cat /dev/urandom | tr -dc '0-9' | fold -w 19 | head -n 1)"
}

# Login and get client token
login() {
    local client_id=$1
    local app_token=$2
    local proxy=${3:-}

    local proxy_option=""
    if [[ -n "$proxy" ]]; then
        proxy_option="--proxy $proxy"
    fi

    response=$(
        curl -s $proxy_option -X POST -H "Content-Type: application/json" \
        -d "{\"appToken\":\"$app_token\",\"clientId\":\"$client_id\",\"clientOrigin\":\"deviceid\"}" \
        "https://api.gamepromo.io/promo/login-client"
    )

    if [[ $? -ne 0 ]]; then
        return
    fi

    echo "$response" | jq -r '.clientToken'
}

# Emulate progress
emulate_progress() {
    local client_token=$1
    local promo_id=$2
    local proxy=${3:-}

    local proxy_option=""
    if [[ -n "$proxy" ]]; then
        proxy_option="--proxy $proxy"
    fi

    response=$(
        curl -s $proxy_option -X POST -H "Authorization: Bearer $client_token" \
        -H "Content-Type: application/json" \
        -d "{\"promoId\":\"$promo_id\",\"eventId\":\"$(uuidgen)\",\"eventOrigin\":\"undefined\"}" \
        "https://api.gamepromo.io/promo/register-event"
    )

    if [[ $? -ne 0 ]]; then
        echo "Error during emulate progress"
        return
    fi

    echo "$response" | jq -r '.hasCode'
}

# Generate promotion key
generate_key() {
    local client_token=$1
    local promo_id=$2
    local proxy=${3:-}

    local proxy_option=""
    if [[ -n "$proxy" ]]; then
        proxy_option="--proxy $proxy"
    fi

    response=$(
        curl -s $proxy_option -X POST -H "Authorization: Bearer $client_token" \
        -H "Content-Type: application/json" \
        -d "{\"promoId\":\"$promo_id\"}" \
        "https://api.gamepromo.io/promo/create-code"
    )

    if [[ $? -ne 0 ]]; then
        echo "Error during generate key"
        return
    fi

    echo "$response" | jq -r '.promoCode'
}

# Send message to Telegram
send_to_telegram() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHANNEL_ID" \
        -d text="$message" \
        -d parse_mode="MarkdownV2" > /dev/null 2>&1
}

# Generate key process for My Clone Army
generate_key_process() {
    local app_token=$1
    local promo_id=$2
    local proxy=$3

    client_id=$(generate_client_id)
    client_token=$(login "$client_id" "$app_token" "$proxy")

    if [[ -z "$client_token" ]]; then
        return
    fi

    for i in {1..55}; do
        sleep $((EVENTS_DELAY * (RANDOM % 3 + 1) / 3))
        has_code=$(emulate_progress "$client_token" "$promo_id" "$proxy")

        if [[ "$has_code" == "true" ]]; then
            break
        fi
    done

    key=$(generate_key "$client_token" "$promo_id" "$proxy")
    echo "$key"
}

# Main function to generate keys and send to Telegram
main() {
    install_dependencies
    load_proxies

    # Game details for My Clone Army
    local game_name="My Clone Army"
    local app_token="74ee0b5b-775e-4bee-974f-63e7f4d5bacb"
    local promo_id="fe693b26-b342-4159-8808-15e3ff7f8767"

    echo -e "${purple}=======${yellow}My Clone Army Key Generator${purple}=======${rest}"
    echo ""
    echo -en "${purple}[Optional] ${green}Enter Your Telegram Bot token: ${rest}"
    read -r TELEGRAM_BOT_TOKEN
    echo -e "${purple}============================${rest}"
    echo -en "${purple}[Optional] ${green}Enter Your Telegram Channel ID [example: ${yellow}@P_Tech2024${green}]: ${rest}"
    read -r TELEGRAM_CHANNEL_ID
    echo -e "${purple}============================${rest}"
    echo -e "${green}Generating keys ... Keys will be saved in [${yellow}my_keys.txt${green}]..${rest}"

    EVENTS_DELAY=20
    PROXY_FILE="proxy.txt"

    while true; do
        if [[ ${#proxies[@]} -gt 0 ]]; then
            proxy=${proxies[RANDOM % ${#proxies[@]}]}
        else
            proxy=""
        fi

        key=$(generate_key_process "$app_token" "$promo_id" "$proxy")

        if [[ -n "$key" ]]; then
            message="${game_name} : $key"
            telegram_message="\`${key}\`"
            echo "$message" | tee -a my_keys.txt
            send_to_telegram "$telegram_message"
        else
            echo "Error generating key for $game_name"
        fi

        sleep 10 # wait
    done
}

main

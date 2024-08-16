#!/bin/bash# Colors
yellow='\033[0;33m'
purple='\033[0;35m'
green='\033[0;32m'
rest='\033[0m'# Function to check and install required packagesinstall_dependencies() {
    if ! command -v jq &> /dev/null; then# Check if the environment is Termuxif [ -n "$TERMUX_VERSION" ]; then
            pkg update -y
            pkg install -y jq
        else
            apt update -y && apt install -y jq
        fifiif ! command -v uuidgen &> /dev/null; then# Check if the environment is Termuxif [ -n "$TERMUX_VERSION" ]; then
            pkg install uuid-utils -y
        else
            apt update -y && apt install uuid-runtime -y
        fifi
}

# Function to load proxies from a fileload_proxies() {
    if [[ -f "$1" ]]; thenmapfile -t proxies <"$1"elseecho -e "${yellow}Proxy file not found. We continue without a proxy.${rest}"
        proxies=()
    fi
}

# Function to generate a client IDgenerate_client_id() {
    echo"$(date +%s%3N)-$(cat /dev/urandom | tr -dc '0-9' | fold -w 19 | head -n 1)"
}

# Function to log in and get a client tokenlogin() {
    local client_id=$1local app_token=$2local proxy=${3:-}local proxy_option=""if [[ -n "$proxy" ]]; then
        proxy_option="--proxy $proxy"fi

    response=$(
        curl -s $proxy_option -X POST -H "Content-Type: application/json" \
        -d "{\"appToken\":\"$app_token\",\"clientId\":\"$client_id\",\"clientOrigin\":\"deviceid\"}" \
        "https://api.gamepromo.io/promo/login-client"
    )

    if [[ $? -ne 0 ]]; thenreturnfiecho"$response" | jq -r '.clientToken'
}

# Function to emulate progressemulate_progress() {
    local client_token=$1local promo_id=$2local proxy=${3:-}local proxy_option=""if [[ -n "$proxy" ]]; then
        proxy_option="--proxy $proxy"fi

    response=$(
        curl -s $proxy_option -X POST -H "Authorization: Bearer $client_token" \
        -H "Content-Type: application/json" \
        -d "{\"promoId\":\"$promo_id\",\"eventId\":\"$(uuidgen)\",\"eventOrigin\":\"undefined\"}" \
        "https://api.gamepromo.io/promo/register-event"
    )

    if [[ $? -ne 0 ]]; thenecho"Error during emulate progress"returnfiecho"$response" | jq -r '.hasCode'
}

# Function to generate a promotion keygenerate_key() {
    local client_token=$1local promo_id=$2local proxy=${3:-}local proxy_option=""if [[ -n "$proxy" ]]; then
        proxy_option="--proxy $proxy"fi

    response=$(
        curl -s $proxy_option -X POST -H "Authorization: Bearer $client_token" \
        -H "Content-Type: application/json" \
        -d "{\"promoId\":\"$promo_id\"}" \
        "https://api.gamepromo.io/promo/create-code"
    )

    if [[ $? -ne 0 ]]; thenecho"Error during generate key"returnfiecho"$response" | jq -r '.promoCode'
}

# Function to send a message to Telegramsend_to_telegram() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHANNEL_ID" \
        -d text="$message" \
        -d parse_mode="MarkdownV2" > /dev/null 2>&1
}

# Function to generate a key processgenerate_key_process() {
    local app_token=$1local promo_id=$2local proxy=$3

    client_id=$(generate_client_id)
    client_token=$(login "$client_id""$app_token""$proxy")

    if [[ -z "$client_token" ]]; thenreturnfifor i in {1..20}; dosleep $((EVENTS_DELAY * (RANDOM % 4 + 1) / 3))
        has_code=$(emulate_progress "$client_token""$promo_id""$proxy")

        if [[ "$has_code" == "true" ]]; thenbreakfidone

    key=$(generate_key "$client_token""$promo_id""$proxy")
    echo"$key"
}

# Main functionmain() {
    install_dependencies
    load_proxies "$PROXY_FILE"whiletrue; do
        game_choice=1 # Only Twerk Race 3Dif [[ ${#proxies[@]} -gt 0 ]]; then
            proxy=${proxies[RANDOM % ${#proxies[@]}]}else
            proxy=""fi

        key=$(generate_key_process "${games[$game_choice, appToken]}""${games[$game_choice, promoId]}""$proxy")

        if [[ -n "$key" ]]; then
            message="${games[$game_choice, name]} : $key"
            telegram_message="\`${key}\`"echo"$message" | tee -a my_keys.txt
            send_to_telegram "$telegram_message"elseecho"Error generating key for ${games[$game_choice, name]}"fisleep 10 # waitdone
}

# Define the gamesdeclare -A games
games[1, name]="Twerk Race 3D"
games[1, appToken]="61308365-9d16-4040-8bb0-2f4a4c69074c"
games[1, promoId]="61308365-9d16-4040-8bb0-2f4a4c69074c"

EVENTS_DELAY=20
PROXY_FILE="proxy.txt"

main

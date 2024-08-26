#!/bin/bash

# Colors for output
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
blue='\033[0;34m'
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

    # If any package is missing, install them
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

# Clear the screen and print the header
clear
echo -e "${purple}=======${yellow} Hamster Combat Auto Clicker${purple}=======${rest}"
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# Prompt for coin capacity threshold
echo -en "${green}Enter Coin Capacity [${yellow}default:5000${green}]:${rest} "
read -r capacity
capacity=${capacity:-5000}

# Function to generate random Gaussian delay
generate_gaussian_delay() {
    mean=$1
    stddev=$2
    u1=$(awk "BEGIN {srand(); print rand()}")
    u2=$(awk "BEGIN {srand(); print rand()}")
    z=$(awk "BEGIN {print sqrt(-2*log($u1))*cos(2*3.14159265358979*$u2)}")
    delay=$(awk "BEGIN {print $mean + $stddev * $z}")

    if (( $(echo "$delay < 0" | bc -l) )); then
        delay=0.1
    fi
    echo "$delay"
}

# Function to calculate the sleep time based on a fixed range
calculate_sleep_time() {
    sleep_time=$(generate_gaussian_delay 2400 600)
    sleep_time=$(awk "BEGIN {print ($sleep_time < 1200) ? 1200 : ($sleep_time > 3600) ? 3600 : $sleep_time}")

    echo "$sleep_time"
}

# Function to convert text to Morse code
text_to_morse() {
    local text="$1"
    declare -A morse_code_map=(
        [A]=".-" [B]="-..." [C]="-.-." [D]="-.." [E]="." [F]="..-."
        [G]="--." [H]="...." [I]=".." [J]=".---" [K]="-.-" [L]=".-.."
        [M]="--" [N]="-." [O]="---" [P]=".--." [Q]="--.-" [R]=".-."
        [S]="..." [T]="-" [U]="..-" [V]="...-" [W]=".--" [X]="-..-"
        [Y]="-.--" [Z]="--.." [0]="-----" [1]=".----" [2]="..---" [3]="...--"
        [4]="....-" [5]="....." [6]="-...." [7]="--..." [8]="---.." [9]="----."
    )

    local morse=""
    local char
    for ((i = 0; i < ${#text}; i++)); do
        char="${text:$i:1}"
        morse+="${morse_code_map[$char]} "
    done

    echo "$morse"
}

# Function to send tap request with a specific symbol
send_tap_request() {
    local symbol="$1"
    local count
    case "$symbol" in
    "-")
        count=1
        ;;
    ".")
        count=0
        ;;
    *)
        echo -e "${red}Invalid symbol for tap request: $symbol${rest}"
        return
        ;;
    esac
    curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
        -H "Authorization: $Authorization" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{\"count\": $count, \"timestamp\": $(date +%s)}" >/dev/null
}

# Flag to check if daily cipher has been executed
daily_cipher_executed=false

# Main loop
while true; do
    current_hour=$(date +%H)
    current_minute=$(date +%M)

    # Check if it's time to run daily cipher operations
    if { [ "$current_hour" -eq 22 ] && [ "$current_minute" -ge 30 ]; } || { [ "$current_hour" -eq 23 ] && [ "$current_minute" -lt 30 ]; }; then
        if ! $daily_cipher_executed; then
            echo -e "${yellow}Running daily cipher operations...${rest}"

            available_taps=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/sync \
                -H "Content-Type: application/json" \
                -H "Authorization: $Authorization" \
                -d '{}' | jq -r '.clickerUser.availableTaps')

            while [ "$available_taps" -lt 500 ]; do
                echo -e "${purple}Not enough taps. Waiting 120 seconds...${rest}"
                sleep 120
                available_taps=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/sync \
                    -H "Content-Type: application/json" \
                    -H "Authorization: $Authorization" \
                    -d '{}' | jq -r '.clickerUser.availableTaps')
            done

            cipher=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/config \
                -H "Accept: application/json" \
                -H "Authorization: $Authorization" \
                -H "Content-Type: application/json" \
                -d '{}' | jq -r '.dailyCipher.cipher')

            if [ -z "$cipher" ]; then
                echo -e "${red}Error: No cipher received.${rest}"
                exit 1
            fi

            modified_cipher="${cipher:0:3}${cipher:4}"
            decoded_cipher=$(echo "$modified_cipher" | base64 --decode)

            echo -e "${green}Daily Cipher is: ${cyan}$decoded_cipher${rest}"

            morse_code=$(text_to_morse "$decoded_cipher")

            for ((i = 0; i < ${#morse_code}; i++)); do
                symbol="${morse_code:$i:1}"
                case "$symbol" in
                "-")
                    send_tap_request "-"
                    ;;
                ".")
                    send_tap_request "."
                    ;;
                " ")
                    sleep 1
                    ;;
                esac
                sleep 0.5
            done

            response=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/claim-daily-cipher \
                -H "Authorization: $Authorization" \
                -H "Content-Type: application/json" \
                -d "{\"cipher\": \"$decoded_cipher\"}")

            if [ "$(echo "$response" | jq -r '.dailyCipher.isClaimed')" == "true" ]; then
                echo -e "${green}Daily cipher successfully claimed.${rest}"
            else
                echo -e "${red}Failed to claim the daily cipher.${rest}"
            fi

            # Set flag to true to prevent rerunning the cipher operation in the same session
            daily_cipher_executed=true
        fi
    else
        daily_cipher_executed=false
    fi

    # Normal operations of the first script (clickerV2.sh)
    Taps=$(curl -s -X POST \
        https://api.hamsterkombatgame.io/clicker/sync \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" |
        jq '.clickerUser.availableTaps')

    if [ "$Taps" -le 0 ]; then
        echo -e "${yellow}No more taps available. Sleeping now...${rest}"
        continue
    fi

    tap_count=$(shuf -i 10-20 -n 1)
    random_sleep=$(generate_gaussian_delay 2 1)
    sleep $(awk "BEGIN {print $random_sleep}")

    curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
        -d '{
            "availableTaps": '"$Taps"',
            "count": '"$tap_count"',
            "timestamp": '"$(date +%s)"'
        }' >/dev/null

    echo -e "${blue}Taps left: $Taps${rest}"
done

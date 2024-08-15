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

# Function to generate random Gaussian delay
generate_gaussian_delay() {
    mean=$1
    stddev=$2
    # Generate a random number using the Box-Muller transform for Gaussian distribution
    u1=$(awk "BEGIN {srand(); print rand()}")
    u2=$(awk "BEGIN {srand(); print rand()}")
    z=$(awk "BEGIN {print sqrt(-2*log($u1))*cos(2*3.14159265358979*$u2)}")
    delay=$(awk "BEGIN {print $mean + $stddev * $z}")
    
    # Ensure the delay is positive
    if (( $(echo "$delay < 0" | bc -l) )); then
        delay=0.1
    fi
    echo "$delay"
}

# Function to calculate the sleep time based on the current hour
calculate_sleep_time() {
    current_hour=$(date +"%H")

    if [ "$current_hour" -ge 0 ] && [ "$current_hour" -lt 6 ]; then
        # If the time is between midnight and 6 AM, set the maximum sleep time to 2.5 hours (9000 seconds)
        sleep_time=$(generate_gaussian_delay 3600 1800) # mean: 3600 seconds, stddev: 1800 seconds
        sleep_time=$(awk "BEGIN {print ($sleep_time < 600) ? 600 : ($sleep_time > 9000) ? 9000 : $sleep_time}") # Clamping to range 600-9000
    else
        # Otherwise, set the maximum sleep time to 1 hour (3600 seconds)
        sleep_time=$(generate_gaussian_delay 1800 900) # mean: 1800 seconds, stddev: 900 seconds
        sleep_time=$(awk "BEGIN {print ($sleep_time < 600) ? 600 : ($sleep_time > 3600) ? 3600 : $sleep_time}") # Clamping to range 600-3600
    fi

    echo "$sleep_time"
}

while true; do
    # Try to get Taps with retries if needed
    attempt=0
    max_attempts=5
    while [ $attempt -lt $max_attempts ]; do
        Taps=$(curl -s -X POST \
            https://api.hamsterkombatgame.io/clicker/sync \
            -H "Content-Type: application/json" \
            -H "Authorization: $Authorization" \
            -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
            -d '{}' | jq -r '.clickerUser.availableTaps' 2>/dev/null)

        if [ -n "$Taps" ] && [ "$Taps" -ge 0 ]; then
            break
        fi

        attempt=$((attempt + 1))
        echo "Failed to retrieve Taps. Attempt $attempt/$max_attempts"
        sleep 2
    done

    if [ -z "$Taps" ] || [ "$Taps" -lt 0 ]; then
        echo "Failed to retrieve Taps after $max_attempts attempts. Exiting script."
        exit 1
    fi

    if [ "$Taps" -lt 30 ]; then
        echo "Taps are less than 30. Disconnecting and waiting..."

        # Calculate sleep time based on the current hour
        sleep_time=$(calculate_sleep_time)
        
        # Countdown timer
        echo "Reconnecting in $(($sleep_time / 60)) minutes..."
        while [ $sleep_time -gt 0 ]; do
            echo -ne "Time remaining: $sleep_time seconds\033[0K\r"
            sleep 1
            sleep_time=$((sleep_time - 1))
        done

        # Clear screen after countdown
        clear
        echo "Reconnecting now..."
        continue
    fi

    # Randomize the number of taps sent
    tap_count=$(shuf -i 10-20 -n 1)

    # Random sleep time using Gaussian distribution for short delays
    random_sleep=$(generate_gaussian_delay 2 1) # mean: 2 seconds, stddev: 1 second
    sleep $(awk "BEGIN {print $random_sleep}")

    # Use the Firefox user-agent for the request
    curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
        -d '{
            "availableTaps": '"$Taps"',
            "count": '"$tap_count"', 
            "timestamp": '"$(date +%s)"'
        }' > /dev/null

    echo "Taps left: $Taps"
done

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

# Read Authorization and User-Agent from config.txt
config_file="config.txt"
if [ ! -f "$config_file" ]; then
    echo -e "${red}Config file not found! Please create config.txt with the Authorization and User-Agent headers.${rest}"
    exit 1
fi

Authorization=$(grep '^Authorization: Bearer ' "$config_file" | sed 's/^Authorization: Bearer //')
UserAgent=$(grep '^User-Agent: ' "$config_file" | sed 's/^User-Agent: //')

if [ -z "$Authorization" ]; then
    echo -e "${red}Authorization not found in config.txt!${rest}"
    exit 1
fi

if [ -z "$UserAgent" ]; then
    echo -e "${red}User-Agent not found in config.txt!${rest}"
    exit 1
fi

# Fixed click count
tap_count=15

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

# Function to calculate the sleep time based on a fixed range
calculate_sleep_time() {
    # Fixed sleep time range: 20 minutes (1200 seconds) to 1 hour (3600 seconds)
    sleep_time=$(generate_gaussian_delay 2400 600) # mean: 2400 seconds, stddev: 600 seconds
    sleep_time=$(awk "BEGIN {print ($sleep_time < 1200) ? 1200 : ($sleep_time > 3600) ? 3600 : $sleep_time}") # Clamp to range 1200-3600 seconds

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
            -H "Authorization: Bearer $Authorization" \
            -H "User-Agent: $UserAgent" \
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

        # Clear the screen before delaying
        clear
        
        # Calculate sleep time based on a fixed range
        sleep_time=$(calculate_sleep_time)
        
        # Calculate minutes using bc for floating-point division
        minutes=$(echo "scale=2; $sleep_time / 60" | bc)
        
        # Calculate reconnect time
        reconnect_time=$(date -d "$sleep_time seconds" +"%H:%M:%S")
        
        echo "Reconnecting in ${minutes} minutes at ${reconnect_time}..."

        # Use sleep directly without manual countdown
        sleep "$sleep_time"

        # Clear screen after sleep
        clear
        echo "Reconnecting now..."
        continue
    fi

    # Random sleep time using Gaussian distribution for short delays
    random_sleep=$(generate_gaussian_delay 2 1) # mean: 2 seconds, stddev: 1 second
    sleep $(awk "BEGIN {print $random_sleep}")

    # Use the Firefox user-agent for the request
    curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $Authorization" \
        -H "User-Agent: $UserAgent" \
        -d '{
            "availableTaps": '"$Taps"',
            "count": '"$tap_count"', 
            "timestamp": '"$(date +%s)"'
        }' > /dev/null

    echo "Taps left: $Taps"
done

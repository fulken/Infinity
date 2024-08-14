#!/bin/bash

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
blue='\033[0;34m'
rest='\033[0m'

# Retry function to attempt a command with a maximum number of retries
retry_command() {
    local retries=$1
    shift
    local count=0

    until "$@"; do
        exit_code=$?
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            echo -e "${yellow}Retry $count/$retries ...${rest}"
            sleep 1
        else
            echo -e "${red}Command failed after $count attempts.${rest}"
            return $exit_code
        fi
    done
    return 0
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
    # Fetch remaining taps, retry up to 6 times on failure
    retry_command 6 Taps=$(curl -s -X POST \
        https://api.hamsterkombatgame.io/clicker/sync \
        -H "Content-Type: application/json" \
        -H "Authorization: $Authorization" \
        -d '{}' | jq -r '.clickerUser.availableTaps')

    if [ "$Taps" -lt 30 ]; then
        echo "Taps are less than 30. Reducing..."
        # Increase the speed to 5 times faster
        while [ "$Taps" -gt 0 ]; do
            retry_command 6 curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
                -H "Content-Type: application/json" \
                -H "Authorization: $Authorization" \
                -d '{
                    "availableTaps": '"$Taps"',
                    "count": 3,
                    "timestamp": '"$(date +%s)"'
                }' > /dev/null
            sleep 0.2  # 5x speed reduction (original sleep time was 1 second, reduced to 0.2 seconds)
            retry_command 6 Taps=$(curl -s -X POST \
                https://api.hamsterkombatgame.io/clicker/sync \
                -H "Content-Type: application/json" \
                -H "Authorization: $Authorization" \
                -d '{}' | jq -r '.clickerUser.availableTaps')
        done
        echo "Taps reduced below 30. Disconnecting from Hamster server..."
        # Disconnect from the server (custom command depending on your system)
        killall curl  # This line is just an example; replace it with your disconnect command
        sleep 1

        echo "Reconnecting to server within 30 minutes to 1 hour..."
        sleep $((RANDOM % 1800 + 1800))  # Sleep for 30 to 60 minutes

        # Reconnect and empty remaining taps
        echo "Reconnecting now..."
        retry_command 6 Taps=$(curl -s -X POST \
            https://api.hamsterkombatgame.io/clicker/sync \
            -H "Content-Type: application/json" \
            -H "Authorization: $Authorization" \
            -d '{}' | jq -r '.clickerUser.availableTaps')

        while [ "$Taps" -gt 0 ]; do
            retry_command 6 curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
                -H "Content-Type: application/json" \
                -H "Authorization: $Authorization" \
                -d '{
                    "availableTaps": '"$Taps"',
                    "count": 3,
                    "timestamp": '"$(date +%s)"'
                }' > /dev/null
            sleep 0.2
            retry_command 6 Taps=$(curl -s -X POST \
                https://api.hamsterkombatgame.io/clicker/sync \
                -H "Content-Type: application/json" \
                -H "Authorization: $Authorization" \
                -d '{}' | jq -r '.clickerUser.availableTaps')
        done

        echo "Final taps cleared. Disconnecting again."
        killall curl  # Replace with your actual disconnect command
        break
    else
        random_sleep=$(shuf -i 20-60 -n 1)
        sleep $(echo "scale=3; $random_sleep / 1000" | bc)
    fi
done

#!/bin/bash

# تنظیم گزینه‌های خطا برای دیباگ بهتر
set -euo pipefail
# برای نمایش دستورات اجرا شده، خط زیر را کامنت کنید
#set -x

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
blue='\033[0;34m'
rest='\033[0m'

# اگر در Termux اجرا می‌شود، به‌روزرسانی و ارتقاء انجام دهید
if [ -d "$HOME/.termux" ] && [ -z "$(command -v jq)" ]; then
    echo "Running update & upgrade ..."
    pkg update -y
    pkg upgrade -y
fi

# تابع نصب بسته‌های لازم
install_packages() {
    local packages=(curl jq bc)
    local missing_packages=()

    # بررسی بسته‌های گمشده
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    # اگر بسته‌ای گمشده بود، نصب آن‌ها
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

# نصب بسته‌های لازم
install_packages

# پاک کردن صفحه نمایش
clear
echo -e "${purple}=======${yellow} Hamster Combat Auto Clicker${purple}=======${rest}"

# تابع تولید تاخیر گاوسی تصادفی
generate_gaussian_delay() {
    mean=$1
    stddev=$2
    # تولید یک عدد تصادفی با استفاده از تبدیل Box-Muller برای توزیع گاوسی
    u1=$(awk "BEGIN {srand(); print rand()}")
    u2=$(awk "BEGIN {srand(); print rand()}")
    z=$(awk "BEGIN {print sqrt(-2*log($u1))*cos(2*3.14159265358979*$u2)}")
    delay=$(awk "BEGIN {print $mean + $stddev * $z}")

    # اطمینان از مثبت بودن تاخیر
    if (( $(echo "$delay < 0" | bc -l) )); then
        delay=0.1
    fi
    echo "$delay"
}

# تابع محاسبه زمان خواب بر اساس یک بازه ثابت
calculate_sleep_time() {
    # بازه زمان خواب ثابت: 20 دقیقه (1200 ثانیه) تا 1 ساعت (3600 ثانیه)
    sleep_time=$(generate_gaussian_delay 2400 600) # میانگین: 2400 ثانیه، انحراف معیار: 600 ثانیه
    sleep_time=$(awk "BEGIN {print ($sleep_time < 1200) ? 1200 : ($sleep_time > 3600) ? 3600 : $sleep_time}") # محدود کردن به بازه 1200-3600 ثانیه

    echo "$sleep_time"
}

# لیست اکانت‌ها و یوزر ایجنت‌های مربوطه
declare -A accounts
accounts=(
    ["Account1"]="Bearer 1720947826174N7YC23CoYREsermt4OECFKxljykdwuHpWrtJFfurvEdJCNTrxlE6kle8MhlJjaPt1777364098"
    ["Account2"]="Bearer 181825347122kND7C239ERoEfkkygPWhECKOzzrlkutwPdrIFpslwsnXMJKPxhgLgno9NcmBiPbs2374563905"
    # اکانت‌های بیشتر را اینجا اضافه کنید
)

declare -A user_agents
user_agents=(
    ["Account1"]="Mozilla/5.0 (Android 10; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0"
    ["Account2"]="Mozilla/5.0 (iPhone; CPU iPhone OS 13_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.2 Mobile/15E148 Safari/604.1"
    # یوزر ایجنت‌های بیشتر را اینجا اضافه کنید
)

# حلقه اصلی برای اکانت‌ها
for account in "${!accounts[@]}"; do
    Authorization="${accounts[$account]}"
    UserAgent="${user_agents[$account]}"
    echo -e "${cyan}Processing account: $account${rest}"

    while true; do
        # تلاش برای دریافت Taps با تعداد تلاش‌های مشخص
        attempt=0
        max_attempts=5
        while [ $attempt -lt $max_attempts ]; do
            Taps=$(curl -s -X POST \
                https://api.hamsterkombatgame.io/clicker/sync \
                -H "Content-Type: application/json" \
                -H "Authorization: $Authorization" \
                -H "User-Agent: $UserAgent" \
                -d '{}' | jq -r '.clickerUser.availableTaps' 2>/dev/null)

            if [[ "$Taps" != "null" ]] && [ -n "$Taps" ] && [ "$Taps" -ge 0 ]; then
                break
            fi

            attempt=$((attempt + 1))
            echo "Failed to retrieve Taps. Attempt $attempt/$max_attempts"
            sleep 2
        done

        if [ -z "$Taps" ] || [ "$Taps" == "null" ] || [ "$Taps" -lt 0 ]; then
            echo "Failed to retrieve Taps after $max_attempts attempts. Moving to next account."
            break
        fi

        if [ "$Taps" -lt 30 ]; then
            echo "Taps are less than 30. Disconnecting and waiting..."

            # محاسبه زمان خواب بر اساس بازه ثابت
            sleep_time=$(calculate_sleep_time)
            
            # محاسبه دقیقه با استفاده از bc برای تقسیم با اعشار
            minutes=$(echo "scale=2; $sleep_time / 60" | bc)
            
            # محاسبه زمان اتصال مجدد
            reconnect_time=$(date -d "@$(($(date +%s) + $sleep_time))" +"%H:%M:%S")
            
            echo "Reconnecting in ${minutes} minutes at ${reconnect_time}..."

            # استفاده مستقیم از sleep بدون شمارش دستی
            sleep "$sleep_time"

            # پاک کردن صفحه نمایش بعد از خواب
            clear
            echo "Reconnecting now..."
            continue
        fi

        # تصادفی کردن تعداد taps ارسال شده
        tap_count=$(shuf -i 10-20 -n 1)

        # زمان خواب تصادفی با استفاده از توزیع گاوسی برای تاخیرهای کوتاه
        random_sleep=$(generate_gaussian_delay 2 1) # میانگین: 2 ثانیه، انحراف معیار: 1 ثانیه
        sleep "$(awk "BEGIN {print $random_sleep}")"

        # استفاده از یوزر ایجنت Firefox برای درخواست
        curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
            -H "Content-Type: application/json" \
            -H "Authorization: $Authorization" \
            -H "User-Agent: $UserAgent" \
            -d '{
                "availableTaps": '"$Taps"',
                "count": '"$tap_count"', 
                "timestamp": '"$(date +%s)"'
            }' > /dev/null

        echo "Taps left: $Taps"
    done
done

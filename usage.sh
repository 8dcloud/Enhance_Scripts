#!/bin/bash

# Color Variables
RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

# Temporary files for sorting CPU and Memory usage
CPU_TEMP_FILE=$(mktemp)
MEM_TEMP_FILE=$(mktemp)

# Directory containing website UUIDs
WWW_DIR="/var/www"
CGROUP_BASE="/sys/fs/cgroup/websites"

# Function to process a website
process_website() {
    UUID=$1
    CGROUP_PATH="$CGROUP_BASE/$UUID"
    
    if [ ! -d "$CGROUP_PATH" ]; then
        echo -e "${RED}Error: Website ID $UUID not found in cgroup. Skipping.${RESET}"
        return
    fi

    # Get directory owner
    OWNER=$(stat -c "%U" "$WWW_DIR/$UUID" 2>/dev/null)

    # Get CPU Quota and Period
    CPU_MAX=$(cat $CGROUP_PATH/cpu.max 2>/dev/null)
    CPU_QUOTA=$(echo $CPU_MAX | awk '{print $1}')
    CPU_PERIOD=$(echo $CPU_MAX | awk '{print $2}')

    # Convert CPU Quota and Period to milliseconds
    if [[ "$CPU_QUOTA" != "max" ]]; then
        CPU_QUOTA_MS=$((CPU_QUOTA / 1000))
    else
        CPU_QUOTA_MS="Unlimited"
    fi
    CPU_PERIOD_MS=$((CPU_PERIOD / 1000))

    # Compute human-readable vCPU allocation
    if [ "$CPU_QUOTA" == "max" ]; then
        VCPU_ALLOCATION="Unlimited (Full CPU Access)"
    else
        VCPU_ALLOCATION=$(echo "scale=2; $CPU_QUOTA / $CPU_PERIOD" | bc)
    fi

    # Get initial CPU usage
    PREV_CPU_USAGE=$(awk '/usage_usec/ {print $2}' $CGROUP_PATH/cpu.stat 2>/dev/null)
    sleep 1
    CURR_CPU_USAGE=$(awk '/usage_usec/ {print $2}' $CGROUP_PATH/cpu.stat 2>/dev/null)

    # Calculate CPU usage percentage
    CPU_DELTA=$((CURR_CPU_USAGE - PREV_CPU_USAGE))
    if [[ "$CPU_QUOTA" == "max" ]]; then
        CPU_PERCENTAGE="Unlimited"
    else
        CPU_PERCENTAGE=$(echo "scale=2; ($CPU_DELTA * 100) / (CPU_QUOTA * 1000)" | bc 2>/dev/null)
    fi

    # Get Memory Usage
    MEMORY_USAGE=$(cat $CGROUP_PATH/memory.current 2>/dev/null)
    MEMORY_MAX=$(cat $CGROUP_PATH/memory.max 2>/dev/null)
    if [ "$MEMORY_MAX" == "max" ]; then
        MEMORY_MAX=$(grep MemTotal /proc/meminfo | awk '{print $2 * 1024}')
    fi
    MEMORY_USAGE_MB=$((MEMORY_USAGE / 1024 / 1024))
    MEMORY_MAX_MB=$((MEMORY_MAX / 1024 / 1024))
    MEMORY_PERCENTAGE=$(echo "scale=2; ($MEMORY_USAGE / $MEMORY_MAX) * 100" | bc 2>/dev/null)
    
    # Store CPU and memory usage in temporary files
    echo "$UUID $OWNER $CPU_PERCENTAGE" >> "$CPU_TEMP_FILE"
    echo "$UUID $OWNER $MEMORY_USAGE_MB" >> "$MEM_TEMP_FILE"

    # Output results
    echo "--------------------------------------"
    echo "Website ID: $UUID"
    echo "Owner: $OWNER"
    echo "vCPU Allocation: $VCPU_ALLOCATION vCPUs"
    echo "CPU Quota: $CPU_QUOTA_MS ms"
    echo "CPU Period: $CPU_PERIOD_MS ms"
    echo "CPU Usage: $CPU_PERCENTAGE%"
    echo "Memory Usage: $MEMORY_USAGE_MB MB / $MEMORY_MAX_MB MB ($MEMORY_PERCENTAGE%)"
    echo "--------------------------------------"
}

# Handle command-line arguments
if [[ "$1" == "--UUID" && -n "$2" ]]; then
    SEARCH_TERM="$2"
    echo "Searching for UUID: ${SEARCH_TERM} Please be patient..."
    if [ -d "$WWW_DIR/$SEARCH_TERM" ]; then
        process_website "$SEARCH_TERM"
    else
        echo -e "${RED}No match found for UUID '${SEARCH_TERM}'. Exiting...${RESET}"
        exit 1
    fi
    exit 0
elif [[ "$1" == "--OWNER" && -n "$2" ]]; then
    SEARCH_TERM="$2"
    echo "Searching for directory owner: ${SEARCH_TERM} Please be patient..."
    UUID_MATCHES=$(find "$WWW_DIR" -maxdepth 1 -type d -exec stat -c "%U %n" {} + | awk -v term="$SEARCH_TERM" '$1 ~ term {print $2}')

    if [[ -z "$UUID_MATCHES" ]]; then
        echo -e "${RED}No matches found for owner '${SEARCH_TERM}'. Exiting...${RESET}"
        exit 1
    fi

    for UUID in $UUID_MATCHES; do
        process_website "$(basename "$UUID")"
    done
    exit 0
elif [[ "$1" == "--ALL" ]]; then
    echo "Processing all sites..."
    for UUID in $(ls "$WWW_DIR"); do
        process_website "$UUID"
    done
    exit 0
fi

# If no arguments are provided, enter interactive mode
echo "***************************************************************************************"
echo "*                                                                                     *"
echo "*   Do you want to check one/several websites or all websites?                        *"
echo "*   The parameters are 'one' or 'all'                                                 *"
echo "*   Type 1 and press <Enter/Return> to search by UUID/User for 'one/several' sites    *"
echo "*   Type 2 and press <Enter/Return> to output 'all' sites                             *"
echo "*                                                                                     *"
echo "***************************************************************************************"

# Validate user input
while true; do
    read MODE
    if [[ "$MODE" == "1" || "$MODE" == "2" ]]; then
        break
    else
        echo -e "${RED}Invalid input. Please enter only 1 or 2.${RESET}"
    fi
done

if [ "$MODE" == "1" ]; then
    echo "Do you want to search by:"
    echo "1 - UUID"
    echo "2 - Directory Owner"
    read SEARCH_TYPE
    if [ "$SEARCH_TYPE" == "1" ]; then
        echo "Enter full UUID:"
        read SEARCH_TERM
        if [ -d "$WWW_DIR/$SEARCH_TERM" ]; then
            process_website "$SEARCH_TERM"
        else
            echo -e "${RED}No match found for UUID '${SEARCH_TERM}'. Exiting...${RESET}"
            exit 1
        fi
    else
        echo "Enter at least 4-5 characters of the directory owner:"
        read SEARCH_TERM
        UUID_MATCHES=$(find "$WWW_DIR" -maxdepth 1 -type d -exec stat -c "%U %n" {} + | awk -v term="$SEARCH_TERM" '$1 ~ term {print $2}')
        if [[ -z "$UUID_MATCHES" ]]; then
            echo -e "${RED}No matches found for owner '${SEARCH_TERM}'. Exiting...${RESET}"
            exit 1
        fi
        for UUID in $UUID_MATCHES; do
            process_website "$(basename "$UUID")"
        done
    fi
else
    echo "Processing all sites..."
    for UUID in $(ls "$WWW_DIR"); do
        process_website "$UUID"
    done
fi

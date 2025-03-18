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

# Ask user for input mode
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

# Process sites based on user input
if [ "$MODE" == "1" ]; then
    echo "Enter Site UUID or at least 5 characters of the owner name:"
    read SEARCH_TERM
    echo "Now searching for: ${SEARCH_TERM} Please be patient..."

    # Fix: Correctly search for UUID or partial owner match
    UUID_MATCHES=$(find $WWW_DIR -maxdepth 1 -type d -name "$SEARCH_TERM*" -printf "%f\n")

    if [[ -z "$UUID_MATCHES" ]]; then
        echo -e "${RED}No matches found for '${SEARCH_TERM}'. Exiting...${RESET}"
        exit 1
    fi
    
    for UUID in $UUID_MATCHES; do
        process_website "$UUID"
    done
else
    echo "Processing all sites..."
    for UUID in $(ls $WWW_DIR); do
        process_website "$UUID"
    done
fi

# Display top 10 sites by CPU and memory usage
echo "Do you want to see the top 10 sites for CPU and Memory usage? (y/n)"
read SHOW_TOP
if [[ "$SHOW_TOP" == "y" || "$SHOW_TOP" == "Y" ]]; then
    if [[ -s "$CPU_TEMP_FILE" ]]; then
        echo ""
        echo "Top 10 Sites by CPU Usage:"
        sort -k3 -nr "$CPU_TEMP_FILE" | head -10 | awk '{printf "%-40s %-15s %-10s\n", $1, $2, $3 "%"}'
        echo ""
        echo ""
    else
        echo "No CPU usage data available."
    fi
    
    if [[ -s "$MEM_TEMP_FILE" ]]; then
        echo "Top 10 Sites by Memory Usage:"
        sort -k3 -nr "$MEM_TEMP_FILE" | head -10 | awk '{printf "%-40s %-15s %-10s\n", $1, $2, $3 " MB"}'
        echo ""
        echo ""
    else
        echo "No memory usage data available."
    fi
fi

# Clean up temporary files
rm -f "$CPU_TEMP_FILE" "$MEM_TEMP_FILE"

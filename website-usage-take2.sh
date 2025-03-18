#!/bin/bash

# Color Variables
RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

# Temporary files for sorting CPU and Memory usage
CPU_TEMP_FILE=$(mktemp)
MEM_TEMP_FILE=$(mktemp)
UNLIMITED_TEMP_FILE=$(mktemp)

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
        return
    fi

    # Get directory owner
    OWNER=$(stat -c "%U" "$WWW_DIR/$UUID")

    # Get CPU Quota and Period
    CPU_MAX=$(cat $CGROUP_PATH/cpu.max 2>/dev/null)
    CPU_QUOTA=$(echo $CPU_MAX | awk '{print $1}')
    CPU_PERIOD=$(echo $CPU_MAX | awk '{print $2}')

    # Convert CPU Quota from microseconds to milliseconds
    if [[ "$CPU_QUOTA" != "max" ]]; then
        CPU_QUOTA_MS=$((CPU_QUOTA / 1000))
    else
        CPU_QUOTA_MS="Unlimited"
    fi

    # Convert CPU Period from microseconds to milliseconds
    CPU_PERIOD_MS=$((CPU_PERIOD / 1000))

    # Compute human-readable vCPU allocation
    if [ "$CPU_QUOTA" == "max" ]; then
        VCPU_ALLOCATION="Unlimited (Full CPU Access)"
    else
        VCPU_ALLOCATION=$(echo "scale=2; $CPU_QUOTA / $CPU_PERIOD" | bc)
    fi

    # Get Memory Usage
    MEMORY_USAGE=$(cat $CGROUP_PATH/memory.current 2>/dev/null)
    MEMORY_MAX=$(cat $CGROUP_PATH/memory.max 2>/dev/null)
    if [ "$MEMORY_MAX" == "max" ]; then
        MEMORY_MAX=$(grep MemTotal /proc/meminfo | awk '{print $2 * 1024}')
        MEMORY_MAX_LABEL="Unlimited"
    else
        MEMORY_MAX_MB=$((MEMORY_MAX / 1024 / 1024))
        MEMORY_MAX_LABEL="${MEMORY_MAX_MB} MB"
    fi

    MEMORY_USAGE_MB=$((MEMORY_USAGE / 1024 / 1024))
    MEMORY_PERCENTAGE=$(echo "scale=2; ($MEMORY_USAGE / $MEMORY_MAX) * 100" | bc 2>/dev/null)
    
    # Store CPU and memory usage in temporary files
    echo "$UUID $OWNER $CPU_PERCENTAGE" >> "$CPU_TEMP_FILE"
    echo "$UUID $OWNER $MEMORY_USAGE_MB" >> "$MEM_TEMP_FILE"

    # Store sites with unlimited CPU or memory
    if [[ "$CPU_QUOTA" == "max" || "$MEMORY_MAX" == "max" ]]; then
        echo "$UUID $OWNER CPU: $CPU_QUOTA_MS, Memory: $MEMORY_MAX_LABEL" >> "$UNLIMITED_TEMP_FILE"
    fi
}

# Handle Mode 1 (Search by UUID/Owner)
if [ "$MODE" == "1" ]; then
    echo "Enter Site UUID or at least 5 characters of the owner name:"
    read SEARCH_TERM
    UUID_MATCHES=$(ls -l $WWW_DIR | awk -v term="$SEARCH_TERM" '$3 ~ term {print $9}')
    if [[ -z "$UUID_MATCHES" ]]; then
        echo -e "${RED}No matches found for '${SEARCH_TERM}'.${RESET}"
        exit 1
    fi

    echo "How would you like to process the matching sites?"
    echo "1 - See All Matching Sites"
    echo "2 - See Top 10 Matching Sites by CPU/Memory Usage"
    echo "3 - See Matching Sites with Unlimited CPU and/or Memory Resources"

    read VIEW_OPTION
    for UUID in $UUID_MATCHES; do
        process_website "$UUID"
    done
else
    # Handle Mode 2 (All Sites)
    echo "How would you like to process all sites?"
    echo "1 - See All Sites"
    echo "2 - See Top 10 Sites by CPU/Memory Usage"
    echo "3 - See Sites with Unlimited CPU and/or Memory Resources"

    read VIEW_OPTION
    for UUID in $(ls $WWW_DIR); do
        process_website "$UUID"
    done
fi

# Display output based on selection
if [[ "$VIEW_OPTION" == "2" ]]; then
    echo "Top 10 Sites by CPU Usage:"
    sort -k3 -nr "$CPU_TEMP_FILE" | head -10 | awk '{printf "%-40s %-15s %-10s\n", $1, $2, $3 "%"}'
    echo ""

    echo "Top 10 Sites by Memory Usage:"
    sort -k3 -nr "$MEM_TEMP_FILE" | head -10 | awk '{printf "%-40s %-15s %-10s\n", $1, $2, $3 " MB"}'
    echo ""
    rm -f "$CPU_TEMP_FILE" "$MEM_TEMP_FILE"
    exit 0
fi

if [[ "$VIEW_OPTION" == "3" ]]; then
    echo "Sites with Unlimited CPU and/or Memory Resources:"
    if [[ -s "$UNLIMITED_TEMP_FILE" ]]; then
        cat "$UNLIMITED_TEMP_FILE"
    else
        echo "No sites found with unlimited CPU or memory."
    fi
    rm -f "$UNLIMITED_TEMP_FILE"
    exit 0
fi

# Clean up temporary files
rm -f "$CPU_TEMP_FILE" "$MEM_TEMP_FILE" "$UNLIMITED_TEMP_FILE"

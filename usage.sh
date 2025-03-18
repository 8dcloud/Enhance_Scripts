#!/bin/bash

# Color Variables
RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

# Directory containing website UUIDs
WWW_DIR="/var/www"
CGROUP_BASE="/sys/fs/cgroup/websites"

# Ask user for input mode
echo "***************************************************************************************"
echo "*                                                                                     *"
echo "*   Do you want to check one/several website or all websites?                         *"
echo "*   If you choose one you will be asked for a search parameter.                       *"
echo "*   The parameters are 'one' or 'all'                                                 *"
echo "*    - if you choose one, you will be asked for the site UUID                         *"
echo "*        OR the owner of the site folder.                                             *"
echo "*        If you choose UUID then one site will be returned.                           *"
echo "*        If you choose owner, enter 4-5 characters and any site with                  *"
echo "*        an owner matching your input will be provided.                               *"
echo "*   Type 1 and press <Enter/Return> to search by UUID/User for 'one/several' sites    *"
echo "*   Type 2 and press <Enter/Return> to ouput 'all' sites                              *"
echo "*                                                                                     *"
echo "***************************************************************************************"
read MODE


# Function to process a website
process_website() {
    UUID=$1
    CGROUP_PATH="$CGROUP_BASE/$UUID"

    if [ ! -d "$CGROUP_PATH" ]; then
        echo "Error: Website ID $UUID not found in cgroup. Skipping."
        return
    fi

    # Get directory owner
    OWNER=$(stat -c "%U" "$WWW_DIR/$UUID")

    # Get CPU Quota and Period
    CPU_MAX=$(cat $CGROUP_PATH/cpu.max 2>/dev/null)
    CPU_QUOTA=$(echo $CPU_MAX | awk '{print $1}')
    CPU_PERIOD=$(echo $CPU_MAX | awk '{print $2}')

    # Convert CPU Period from microseconds to milliseconds
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
    CPU_PERCENTAGE=$(echo "scale=2; ($CPU_DELTA * 100) / (CPU_QUOTA * 1000)" | bc 2>/dev/null)

    # Get Memory Usage
    MEMORY_USAGE=$(cat $CGROUP_PATH/memory.current 2>/dev/null)
    MEMORY_MAX=$(cat $CGROUP_PATH/memory.max 2>/dev/null)
    if [ "$MEMORY_MAX" == "max" ]; then
        MEMORY_MAX=$(grep MemTotal /proc/meminfo | awk '{print $2 * 1024}')
    fi
    MEMORY_USAGE_MB=$((MEMORY_USAGE / 1024 / 1024))
    MEMORY_MAX_MB=$((MEMORY_MAX / 1024 / 1024))
    MEMORY_PERCENTAGE=$(echo "scale=2; ($MEMORY_USAGE / $MEMORY_MAX) * 100" | bc 2>/dev/null)

    # Output results
    echo "--------------------------------------"
    echo "Website ID: $UUID"
    echo "Owner: $OWNER"
    echo "vCPU Allocation: $VCPU_ALLOCATION vCPUs"
    echo "CPU Quota: $CPU_QUOTA µs (Quota is the max CPU time in a period)"
    echo "CPU Period: $CPU_PERIOD_MS ms (The time window for quota enforcement)"
    echo "CPU Usage: $CPU_PERCENTAGE%"
    echo "Memory Usage: $MEMORY_USAGE_MB MB / $MEMORY_MAX_MB MB ($MEMORY_PERCENTAGE%)"
    echo "--------------------------------------"
}

# Check to see if 1 or 2 was selected
# If 1 is selected, then ask for UUID or 5 characters of owner name
if [ "$MODE" == "1" ]; then
    echo "Enter Site UUID or at least 5 characters of the owner name:"
    read SEARCH_TERM
    echo "Now searching for: ${SEARCH_TERM} Please be patient..."
    echo ""
    echo ""
    if [[ ${#SEARCH_TERM} -ge 5 ]]; then
        UUID_MATCHES=$(ls -l $WWW_DIR | awk -v term="$SEARCH_TERM" '$3 ~ term {print $9}')
    else
        UUID_MATCHES=$SEARCH_TERM
    fi

    for UUID in $UUID_MATCHES; do
        process_website "$UUID"
    done

# If 2 is selected, then simply output all sites found in /var/www
else
    if [ "$MODE" == "2" ]; then
       # If 2 is selected, then simply output all sites found in /var/www
       echo "You have chosen to output statistics for all sites, Please be patient as data is compiled..."
       echo ""
       echo ""
       for UUID in $(ls $WWW_DIR); do
         process_website "$UUID"
       done
    fi
    #If 1 or 2 is not selected...
    echo "You did not choose 1 or 2, please run the script again and be sure to choose only 1 or 2..."
    echo ""
    echo ""
fi

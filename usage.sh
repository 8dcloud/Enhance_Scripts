#!/bin/bash

# Directory containing website UUIDs
WWW_DIR="/var/www"
CGROUP_BASE="/sys/fs/cgroup/websites"

# Ask user for input mode
echo "************************************************************************************"
echo "*   Do you want to check one/several website or all websites?                      *"
echo "*   If you choose one you will be asked for a search parameter.                    *"
echo "*   The parameters are 'one' or 'all'                                              *"
echo "*    - if you choose one, you will be asked for the site UUID                      *"
echo "*        OR the owner of the site folder.                                          *"
echo "*        If you choose UUID then one site will be returned.                        *"
echo "*        If you choose owner, enter 4-5 characters and any site with               *"
echo "*        an owner matching your input will be provided.                            *"
echo "*   Now, type one or all...                                                        *"
echo *************************************************************************************"
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

    # Get number of CPU cores
    CPU_CORES=$(nproc)

    # Calculate CPU limit
    if [ "$CPU_QUOTA" == "max" ]; then
        CPU_LIMIT=$((CPU_CORES * CPU_PERIOD))
    else
        CPU_LIMIT=$CPU_QUOTA
    fi

    # Get initial CPU usage
    PREV_CPU_USAGE=$(awk '/usage_usec/ {print $2}' $CGROUP_PATH/cpu.stat 2>/dev/null)
    sleep 1
    CURR_CPU_USAGE=$(awk '/usage_usec/ {print $2}' $CGROUP_PATH/cpu.stat 2>/dev/null)

    # Calculate CPU usage percentage
    CPU_DELTA=$((CURR_CPU_USAGE - PREV_CPU_USAGE))
    CPU_PERCENTAGE=$(echo "scale=2; ($CPU_DELTA * 100) / $CPU_LIMIT" | bc 2>/dev/null)

    # Get Memory Usage
    MEMORY_USAGE=$(cat $CGROUP_PATH/memory.current 2>/dev/null)
    MEMORY_MAX=$(cat $CGROUP_PATH/memory.max 2>/dev/null)
    if [ "$MEMORY_MAX" == "max" ]; then
        MEMORY_MAX=$(grep MemTotal /proc/meminfo | awk '{print $2 * 1024}')
    fi
    MEMORY_USAGE_MB=$((MEMORY_USAGE / 1024 / 1024))
    MEMORY_MAX_MB=$((MEMORY_MAX / 1024 / 1024))
    MEMORY_PERCENTAGE=$(echo "scale=2; ($MEMORY_USAGE / $MEMORY_MAX) * 100" | bc 2>/dev/null)

    # Get Initial IO Usage
    if [ -f "$CGROUP_PATH/io.stat" ]; then
        read rbytes1 wbytes1 < <(awk '{for (i=1; i<=NF; i++) {if ($i ~ /rbytes=/) r=substr($i, 8); if ($i ~ /wbytes=/) w=substr($i, 8);}} END {print r, w}' $CGROUP_PATH/io.stat)
        rbytes1=${rbytes1:-0}
        wbytes1=${wbytes1:-0}
    else
        rbytes1=0
        wbytes1=0
    fi

    # Wait for 1 second
    sleep 1

    # Get Final IO Usage
    if [ -f "$CGROUP_PATH/io.stat" ]; then
        read rbytes2 wbytes2 < <(awk '{for (i=1; i<=NF; i++) {if ($i ~ /rbytes=/) r=substr($i, 8); if ($i ~ /wbytes=/) w=substr($i, 8);}} END {print r, w}' $CGROUP_PATH/io.stat)
        rbytes2=${rbytes2:-0}
        wbytes2=${wbytes2:-0}
    else
        rbytes2=0
        wbytes2=0
    fi

    # Calculate IO Usage in Bytes per second
    read_speed=$((rbytes2 - rbytes1))
    write_speed=$((wbytes2 - wbytes1))
    total_speed=$((read_speed + write_speed))

    # Convert to MB/s
    read_speed_mb=$(echo "scale=2; $read_speed / 1024 / 1024" | bc 2>/dev/null)
    write_speed_mb=$(echo "scale=2; $write_speed / 1024 / 1024" | bc 2>/dev/null)
    total_speed_mb=$(echo "scale=2; $total_speed / 1024 / 1024" | bc 2>/dev/null)

    # Output results
    echo "--------------------------------------"
    echo "Website ID: $UUID"
    echo "Owner: $OWNER"
    echo "CPU Usage: $CPU_PERCENTAGE%"
    echo "Memory Usage: $MEMORY_USAGE_MB MB / $MEMORY_MAX_MB MB ($MEMORY_PERCENTAGE%)"
    echo "IO Usage: Read $read_speed_mb MB/s, Write $write_speed_mb MB/s, Total $total_speed_mb MB/s"
    echo "--------------------------------------"
}

if [ "$MODE" == "one" ]; then
    echo "Enter UUID or at least 5 characters of the owner name:"
    read SEARCH_TERM

    if [[ ${#SEARCH_TERM} -ge 5 ]]; then
        UUID_MATCHES=$(ls -l $WWW_DIR | awk -v term="$SEARCH_TERM" '$3 ~ term {print $9}')
    else
        UUID_MATCHES=$SEARCH_TERM
    fi

    for UUID in $UUID_MATCHES; do
        process_website "$UUID"
    done
else
    for UUID in $(ls $WWW_DIR); do
        process_website "$UUID"
    done
fi

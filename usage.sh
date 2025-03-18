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

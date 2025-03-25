#!/bin/bash

# Get the current date
DATE=$(date +"%Y-%m-%d")

# Define the inventory file and playbook file
INVENTORY_FILE="Enhance_hosts.ini"
PLAYBOOK_FILE="update_Enhance.yml"
LOG_FILE="logs/ENHANCE_ansible_update_$DATE.log"

# Run the Ansible playbook and save the output to the log file
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" | tee "$LOG_FILE"

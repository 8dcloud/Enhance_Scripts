# This readme is a fast help, I will atempt to update later
## Make sure to Install Ansible on control server as well as all the cluster servers
- It is a good idea to apt update && apt upgrade -y the first time
- on the control server, make a folder such as /root/playbooks
- upload the 3 files: 
--Enhance_hosts.ini - where you define the hosts on which to run the ansible script
--update_Enhance.yml - the actual playbook file
--update_Enhance.sh - the bash script to call the playbook
## give execute perms to the update_Enhance.sh file (or run using sh command)
## You will need to create an ssh key on the contol server (the server from which you run the ansible script)
-- Add the id_rsa.pub from the control server to each server you want to update. Be sure to ssh root@server.com so the known_hosts file is properly updaged **before** you run the playbook
## BE SURE TO TEST FIRST, perhaps on a new vm.

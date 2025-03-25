# Enhance Control Panel – Ansible Update Guide

> ⚠️ This is a quick-start guide. It will be improved and expanded over time.

This project uses **Ansible** to update all servers in your Enhance Control Panel cluster efficiently.

---

## ⚙️ Prerequisites

### 1. Install Ansible

Ansible must be installed on **both** the control server (the one you’ll run the playbook from) and **all** cluster servers:

```bash
apt-get update && apt-get install ansible -y
```

### 2. Update All Servers

Before using Ansible for updates, it’s good practice to make sure all servers are fully upgraded:

```bash
apt-get update && apt-get dist-upgrade -y
```

---

## 📂 Setup Instructions

1. On the **control server**, create a directory to store your playbook files:

```bash
mkdir -p /root/playbooks
cd /root/playbooks
```

2. Upload the following three files into that folder:

- `Enhance_hosts.ini` – defines the hosts for Ansible
- `update_Enhance.yml` – the actual Ansible playbook
- `update_Enhance.sh` – a helper bash script to run the playbook

---

## 🔐 SSH Access Setup

Ansible uses SSH to communicate with your servers. You’ll need to:

1. **Generate an SSH key** on the control server if you haven't already:

```bash
ssh-keygen -t rsa
```

2. **Copy the public key** to each server you want to update:

```bash
ssh-copy-id root@your.server.ip
```

3. **Manually SSH into each server once** to accept its fingerprint:

```bash
ssh root@your.server.ip
```

This ensures the host is added to `~/.ssh/known_hosts`.

---

## ▶️ Running the Update

Make sure `update_Enhance.sh` is executable:

```bash
chmod +x update_Enhance.sh
```

Then run it from the control server:

```bash
./update_Enhance.sh
```

Alternatively, you can run the playbook manually:

```bash
ansible-playbook -i Enhance_hosts.ini update_Enhance.yml
```

---

## 🚫 Optional: Disable Reboot

If you **do not want servers to reboot** automatically, **comment out or remove** the following block from `update_Enhance.yml`:

```yaml
- name: Reboot the server if necessary
  ansible.builtin.reboot:
  when: reboot_required.stat.exists
```

---

## ⚠️ Final Notes

- Always **test first**, ideally on a new virtual machine or non-production server.
- You must run the Ansible commands as **root** or with sufficient privileges.

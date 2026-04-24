#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

read -p "Enter the VM ID (VMID): " VMID

CLOUD_IMAGE="jammy-server-cloudimg-amd64.img"
IMAGE_DIR="/var/lib/vz/template/qemu"
IMAGE_PATH="${IMAGE_DIR}/${CLOUD_IMAGE}"

DISK_SIZE="30"
CORES=1
MEMORY=1024
IPV4="10.24.50.${VMID}"
IPV4_CIDR="10.24.50.${VMID}/24"
GATEWAY="10.24.50.1"
DNS_SERVER="1.1.1.1"
BRIDGE="vmbr0"
STORAGE="shared-harddisk-pool"
ZABBIX_SERVER="10.24.50.110"

printf "\n==============================\n"
printf "Make VM for WordPress\n"
printf "==============================\n"

# ==============================
# Check cloud image
# ==============================

printf "\n==============================\n"
printf "Checking if cloud image exists...\n"

if [ ! -f "$IMAGE_PATH" ]; then
    printf "Ubuntu cloud image does not exist, use vm_bash_download_img.sh to download.\n"
    exit 1
else
    printf "Cloud image already exists\n"
fi

# ==============================
# Check SSH key
# ==============================

printf "\n==============================\n"
printf "Checking SSH key...\n"

if [ ! -f ~/.ssh/id_rsa.pub ]; then
    printf "ERROR: SSH key not found at ~/.ssh/id_rsa.pub\n"
    printf "Generate one with: ssh-keygen -t rsa -b 4096\n"
    exit 1
else
    printf "SSH key found\n"
fi

SSH_KEY=$(cat ~/.ssh/id_rsa.pub)

# ==============================
# Check / cleanup existing VM
# ==============================

printf "\n==============================\n"
printf "Checking if VM ID %s exists...\n" "$VMID"

if qm status "$VMID" >/dev/null 2>&1; then

    printf "VM %s already exists, stopping VM...\n" "$VMID"
    qm stop "$VMID" || true

    printf "Waiting for VM to stop...\n"
    while qm status "$VMID" | grep -q "running"; do
        sleep 1
        printf "."
    done

    printf "\nDeleting VM %s...\n" "$VMID"
    qm destroy "$VMID" --purge

fi

printf "VM ID %s is available\n" "$VMID"

# ==============================
# Create VM
# ==============================

printf "\n==============================\n"
printf "Creating VM...\n"
printf "==============================\n\n"

qm create "$VMID" \
    --name "wordpress-$VMID" \
    --cores "$CORES" \
    --memory "$MEMORY" \
    --sockets 1 \
    --cpu host \
    --net0 "virtio,bridge=${BRIDGE},macaddr=52:54:00:12:34:$(printf '%02x' $((VMID % 256))),rate=50" \
    --scsihw virtio-scsi-single \
    --ostype l26 \
    --agent enabled=1

# ==============================
# Import cloud image as boot disk
# ==============================

printf "\n==============================\n"
printf "Importing cloud image as boot disk...\n"

qm importdisk "$VMID" "$IMAGE_PATH" "$STORAGE"
qm set "$VMID" --scsi0 "${STORAGE}:vm-${VMID}-disk-0,discard=on"

# Resize disk to desired size
qm disk resize "$VMID" scsi0 "${DISK_SIZE}G"

# ==============================
# Attach Proxmox native cloud-init drive
# ==============================

printf "\n==============================\n"
printf "Attaching cloud-init drive...\n"

qm set "$VMID" --ide2 "${STORAGE}:cloudinit"

# ==============================
# Configure boot order
# ==============================

printf "\n==============================\n"
printf "Configuring boot order...\n"

qm set "$VMID" \
    --boot order=scsi0 \
    --bootdisk scsi0

# ==============================
# Configure network via Proxmox cloud-init
# Geen --ciuser of --sshkeys meer — dit gaat via het snippet
# ==============================

printf "\n==============================\n"
printf "Configuring network via cloud-init...\n"

qm set "$VMID" \
    --ipconfig0 "ip=${IPV4_CIDR},gw=${GATEWAY}" \
    --nameserver "${DNS_SERVER}"

# ==============================
# Maak cloud-init snippet aan
# User aanmak, SSH key en packages volledig via snippet
# ==============================

printf "\n==============================\n"
printf "Creating cloud-init snippet...\n"

SNIPPET_DIR="/var/lib/vz/snippets"
mkdir -p "$SNIPPET_DIR"

USERDATA_FILE="${SNIPPET_DIR}/wordpress-${VMID}-userdata.yaml"

cat > "$USERDATA_FILE" << USERDATA
#cloud-config
hostname: wordpress-${VMID}
fqdn: wordpress-${VMID}.local
manage_etc_hosts: true
timezone: Europe/Amsterdam

package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent
  - openssh-server
  - ufw
  - wget
  - curl
  - gnupg

locale: en_US.UTF-8

users:
  - name: ansible
    gecos: Ansible User
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ${SSH_KEY}

bootcmd:
  - locale-gen en_US.UTF-8
  - update-locale LANG=en_US.UTF-8

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - systemctl restart qemu-guest-agent

  - sudo wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu22.04_all.deb
  - sudo dpkg -i zabbix-release_latest_7.0+ubuntu22.04_all.deb
  - sudo apt update
  - sudo apt install -y zabbix-agent2

  - mkdir -p /etc/zabbix
  - sudo sed -i 's/^Server=.*/Server=10.24.50.110/' /etc/zabbix/zabbix_agent2.conf
  - sudo sed -i 's/^ServerActive=.*/ServerActive=10.24.50.110/' /etc/zabbix/zabbix_agent2.conf
  - sudo sed -i 's/^Hostname=.*/Hostname=wordpress-${VMID}/' /etc/zabbix/zabbix_agent2.conf
  - sudo sed -i 's/^# HostInterface=.*/HostInterface=10.24.50.${VMID}/' /etc/zabbix/zabbix_agent2.conf

  - systemctl enable zabbix-agent2
  - systemctl start zabbix-agent2
  - systemctl restart zabbix-agent2

  - ufw --force enable
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw allow 10050/tcp
USERDATA

printf "Snippet aangemaakt: %s\n" "$USERDATA_FILE"

# Koppel snippet aan VM
qm set "$VMID" --cicustom "user=local:snippets/wordpress-${VMID}-userdata.yaml"

# ==============================
# Start VM
# ==============================

printf "\n==============================\n"
printf "Starting VM...\n"
printf "==============================\n"

qm start "$VMID"

printf "\n==============================\n"
printf "Waiting for cloud-init to complete...\n"
printf "This may take 2-3 minutes...\n"
sleep 120

# ==============================
# Wait for QEMU Guest Agent
# ==============================

printf "\nWaiting for QEMU Guest Agent to respond...\n"
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if qm guest exec "$VMID" -- true >/dev/null 2>&1; then
        printf "QEMU Guest Agent is responding\n"
        break
    fi
    printf "."
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    printf "\nQEMU Guest Agent not responding after timeout\n"
    printf "Cloud-init may still be running. Check with:\n"
    printf "  qm guest exec %s -- cat /var/log/cloud-init-output.log\n" "$VMID"
    exit 1
fi

# ==============================
# Verify ansible user
# ==============================

printf "\n==============================\n"
printf "Verifying ansible user...\n"

if qm guest exec "$VMID" -- id ansible >/dev/null 2>&1; then
    printf "Ansible user bestaat en is correct aangemaakt\n"
else
    printf "ERROR: ansible user niet gevonden na cloud-init\n"
    printf "Controleer het cloud-init log:\n"
    printf "  qm guest exec %s -- cat /var/log/cloud-init-output.log\n" "$VMID"
    exit 1
fi

# Controleer authorized_keys
printf "\nControleren SSH authorized_keys...\n"
qm guest exec "$VMID" -- cat /home/ansible/.ssh/authorized_keys

# ==============================
# Verify Zabbix agent
# ==============================

printf "\n==============================\n"
printf "Verifying Zabbix Agent...\n"

qm guest exec "$VMID" -- systemctl status zabbix-agent2 || printf "Zabbix agent check mislukt, controleer handmatig\n"

# ==============================
# Summary
# ==============================

printf "\n==============================\n"
printf "VM %s is ready!\n" "$VMID"
printf "==============================\n"

printf "\nVM Details:\n"
printf "  VM ID:          %s\n" "$VMID"
printf "  Name:           wordpress-%s\n" "$VMID"
printf "  Cores:          %s\n" "$CORES"
printf "  Memory:         %s MB\n" "$MEMORY"
printf "  Disk Size:      %s GB\n" "$DISK_SIZE"
printf "  IP Address:     %s\n" "$IPV4_CIDR"
printf "  Gateway:        %s\n" "$GATEWAY"
printf "  DNS:            %s\n" "$DNS_SERVER"
printf "  Zabbix Server:  %s\n" "$ZABBIX_SERVER"

printf "\n==============================\n"
printf "Next steps:\n"
printf "==============================\n"
printf "\n1. SSH into VM:\n"
printf "   ssh ansible@%s\n\n" "$IPV4"
printf "2. Run WordPress install script:\n"
printf "   ./vm_bash_install_wordpress.sh\n\n"
printf "==============================\n\n"

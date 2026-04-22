#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

read -p "Enter the VM ID (VMID): " VMID
ISO_PATH="local:iso/ubuntu-22.04.5-desktop-amd64.iso"
DISK_SIZE="40"
CORES=2
MEMORY=2048
IPV4="10.24.50.${VMID}/24"
GATEWAY="10.24.50.1"
BRIDGE="vmbr0"
STORAGE="shared-harddisk-pool"

printf "\n==============================\n"
printf "Create KVM VM for WordPress\n"

printf "\n==============================\n"
printf "Checking if ISO exists...\n"
if ! ls -la /var/lib/vz/template/iso/ | grep -q "ubuntu-22.04.5-desktop-amd64.iso"; then
    printf "\n==============================\n"
    printf "ISO not found in local storage.\n"
    exit 1
fi

printf "\n==============================\n"
printf "Checking if VM ID %s exists...\n" "$VMID"
if qm status "$VMID" >/dev/null 2>&1; then

    printf "\n==============================\n"
    printf "VM %s already exists, stopping VM...\n" "$VMID"
    qm stop "$VMID" || true

    printf "\n==============================\n"
    printf "Waiting for VM to stop...\n"
    while qm status "$VMID" | grep -q "running"; do
        sleep 1
        printf ". "
    done

    printf "\n==============================\n"
    printf "Deleting VM %s...\n" "$VMID"
    qm destroy "$VMID"

fi

printf "\n==============================\n"
printf "Creating VM...\n"
printf "\n==============================\n\n"

qm create "$VMID" \
    --name "wordpress-$VMID" \
    --cores "$CORES" \
    --memory "$MEMORY" \
    --sockets 1 \
    --cpu host \
    --net0 "virtio,bridge=${BRIDGE},macaddr=52:54:00:12:34:$(printf '%02x' $((VMID % 256)))" \
    --scsihw virtio-scsi-pci \
    --scsi0 "${STORAGE}:${DISK_SIZE}" \
    --boot order=scsi0 \
    --ide2 "${ISO_PATH},media=cdrom" \
    --ostype l26 \
    --agent enabled=1 \
    --serial0 socket \
    --vga serial0

printf "\n==============================\n"
printf "Setting up cloud-init (if needed for automated installation)\n"
printf "\n==============================\n"

printf "\n==============================\n"
printf "Starting VM...\n"
qm start "$VMID"

printf "\n==============================\n"
printf "Waiting for VM to start...\n"
sleep 10

printf "\n==============================\n"
printf "VM %s has been created and started.\n" "$VMID"
printf "Please complete the Ubuntu installation manually using the console.\n"
printf "Once Ubuntu is installed, run the WordPress installation script.\n"

printf "\n==============================\n"
printf "VM Details:\n"
printf "VM ID: %s\n" "$VMID"
printf "Name: wordpress-%s\n" "$VMID"
printf "IP: %s\n" "$IPV4"
printf "Gateway: %s\n" "$GATEWAY"
printf "\n==============================\n"
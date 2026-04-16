#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

read -p "Enter the container ID (CTID): " CTID
HOSTNAME="wordpress-lxc"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
PASSWORD="password"
DISK_SIZE="30"
CORES=1
MEMORY=1024
IPV4="10.24.50.${CTID}/24"
GATEWAY="10.24.50.1"
DNS_SERVER="1.1.1.1"
BRIDGE="vmbr0"
STORAGE="shared-harddisk-pool"
USERNAME="ansible"

printf "\n==============================\n"
printf "make LXC for WordPress\n"

printf "\n==============================\n"
printf "does the template exists...\n"
if ! pveam list local | grep -q "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"; then
printf "\n==============================\n"
  printf "template not found in local storage.\n"
  exit 1
fi

printf "\n==============================\n"
printf "does LXC ID %s exist...\n" "$CTID"
if pct status "$CTID" >/dev/null 2>&1; then

  printf "\n==============================\n"
  printf "container %s already exists, stopping LXC...\n" "$CTID"
  pct stop "$CTID" || true

  printf "\n==============================\n"
  printf "waiting for LXC to stop...\n"
  while pct status "$CTID" | grep -q "running"; do
    sleep 1
    printf ". "
  done

  printf "\n==============================\n"
  printf "deleting LXC %s...\n" "$CTID"
  pct destroy "$CTID"

fi

printf "\n==============================\n"
printf "make LXC...\n"
printf "\n==============================\n\n"

#    --net0 "name=eth0,bridge=${BRIDGE},ip=${IPV4},gw=${GATEWAY},rate=50" \

pct create "$CTID" "$TEMPLATE" \
    --hostname "$HOSTNAME" \
    --cores "$CORES" \
    --memory "$MEMORY" \
    --rootfs "${STORAGE}:${DISK_SIZE}" \
    --unprivileged 1 \
    --net0 "name=eth0,bridge=${BRIDGE},ip=${IPV4},gw=${GATEWAY}" \
    --nameserver "$DNS_SERVER" \
    --password "$PASSWORD" \
    --features nesting=1

printf "\n==============================\n"
printf "start LXC...\n"
pct start "$CTID"

printf "\n==============================\n"
printf "waiting for LXC to start...\n"
while ! pct status "$CTID" | grep -q "running"; do
  sleep 1
  printf ". "
done

printf "\n==============================\n"
printf "update container\n"
printf "\n==============================\n"

pct exec "$CTID" -- apt update

printf "\n==============================\n"
printf "fix locale settings\n"
printf "\n==============================\n"

pct exec "$CTID" -- apt install -y locales
pct exec "$CTID" -- locale-gen en_US.UTF-8
pct exec "$CTID" -- update-locale LANG=en_US.UTF-8

printf "\n==============================\n"
printf "create user and setup SSH access\n"
pct exec "$CTID" -- useradd -m -s /bin/bash "$USERNAME"
pct exec "$CTID" -- usermod -aG sudo "$USERNAME"
pct exec "$CTID" -- mkdir -p /home/"$USERNAME"/.ssh
pct exec "$CTID" -- bash -c "cat >> /home/$USERNAME/.ssh/authorized_keys" < ~/.ssh/id_rsa.pub
pct exec "$CTID" -- chown -R "$USERNAME:$USERNAME" /home/"$USERNAME"/.ssh
pct exec "$CTID" -- chmod 700 /home/"$USERNAME"/.ssh
pct exec "$CTID" -- chmod 600 /home/"$USERNAME"/.ssh/authorized_keys

printf "\n==============================\n"
printf "configure sudoers for passwordless sudo\n"
pct exec "$CTID" -- bash -c "echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/$USERNAME"
pct exec "$CTID" -- chmod 440 /etc/sudoers.d/"$USERNAME"

printf "\n==============================\n"
printf "configure firewall\n"
pct exec "$CTID" -- apt install -y ufw
pct exec "$CTID" -- ufw --force enable
pct exec "$CTID" -- ufw default deny incoming
pct exec "$CTID" -- ufw default allow outgoing
pct exec "$CTID" -- ufw allow 22/tcp
pct exec "$CTID" -- ufw allow 80/tcp
pct exec "$CTID" -- ufw allow 443/tcp

printf "\n==============================\n"
printf "LXC: %s is ready and able.\n" "$CTID"
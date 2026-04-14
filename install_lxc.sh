#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

CTID=150
HOSTNAME="wordpress-lxc"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
PASSWORD="password"
DISK_SIZE="8"
CORES=1
MEMORY=1024
IPV4="10.24.50.${CTID}/24"
GATEWAY="10.24.50.1"
DNS_SERVER="1.1.1.1"
BRIDGE="vmbr0"
#STORAGE="shared-harddisk-pool"
STORAGE="local-lvm"

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
    printf "container %s already exists, choose another id.\n" "$CTID"
    exit 1
fi

printf "\n==============================\n"
printf "make LXC...\n"
printf "\n==============================\n\n"

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
printf "LXC: %s is ready and able.\n" "$CTID"
#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

# ==============================
# Cloud Image setup
# ==============================

CLOUD_IMAGE="jammy-server-cloudimg-amd64.img"
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/${CLOUD_IMAGE}"
IMAGE_DIR="/var/lib/vz/template/qemu"
IMAGE_PATH="${IMAGE_DIR}/${CLOUD_IMAGE}"

printf "\n==============================\n"
printf "Make VM for WordPress\n"
printf "==============================\n"

# ==============================
# Download cloud image if needed
# ==============================

printf "\n==============================\n"
printf "Checking if cloud image exists...\n"

if [ ! -f "$IMAGE_PATH" ]; then
    printf "Downloading Ubuntu cloud image...\n"
    mkdir -p "$IMAGE_DIR"
    wget -O "$IMAGE_PATH" "$CLOUD_IMAGE_URL"
    printf "✓ Cloud image downloaded\n"
else
    printf "✓ Cloud image already exists\n"
fi

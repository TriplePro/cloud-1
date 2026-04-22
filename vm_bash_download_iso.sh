#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

ISO_NAME="ubuntu-22.04.5-desktop-amd64.iso"
ISO_URL="https://releases.ubuntu.com/jammy/${ISO_NAME}"
ISO_DIR="/var/lib/vz/template/iso"
ISO_PATH="${ISO_DIR}/${ISO_NAME}"

printf "\n==============================\n\n"

printf "Downloading Ubuntu ISO for WordPress VM installation\n"

printf "\n==============================\n\n"
printf "Creating ISO directory if it does not exist\n"

mkdir -p "$ISO_DIR"

printf "\n==============================\n\n"
printf "Downloading ISO if it does not exist\n"

printf "\n==============================\n\n"
if [ -f "$ISO_PATH" ]; then
    printf "ISO already downloaded: %s\n" "$ISO_PATH"
else
    printf "Downloading ISO...\n"
    printf "\n==============================\n\n"
    wget -O "$ISO_PATH" "$ISO_URL"

    printf "\n==============================\n\n"
    printf "Download complete: %s\n" "$ISO_PATH"
fi

printf "\n==============================\n\n"
printf "ISO ready to use.\n\n"
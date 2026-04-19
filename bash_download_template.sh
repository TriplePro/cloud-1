#!/usr/bin/env bash
clear

set -e          # stop on error
set -u          # stop on undefined variable
set -o pipefail # stop if one | of | the options fail

TEMPLATE_NAME="ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
TEMPLATE_URL="http://download.proxmox.com/images/system/${TEMPLATE_NAME}"
TEMPLATE_DIR="/var/lib/vz/template/cache"
TEMPLATE_PATH="${TEMPLATE_DIR}/${TEMPLATE_NAME}"

printf "\n==============================\n\n"

printf "LXC template downloaden voor later WordPress installatie\n"

printf "\n==============================\n\n"
printf "make template dir if not exists\n"

mkdir -p "$TEMPLATE_DIR"

printf "\n==============================\n\n"
printf "download template if not exists\n"

printf "\n==============================\n\n"
if [ -f "$TEMPLATE_PATH" ]; then
    printf "template already downloaded: %s\n" "$TEMPLATE_PATH"
else
    printf "downloading template...\n"
    printf "\n==============================\n\n"
    wget -O "$TEMPLATE_PATH" "$TEMPLATE_URL"

    printf "\n==============================\n\n"
    printf "download compleet: %s\n" "$TEMPLATE_PATH"
fi

printf "\n==============================\n\n"
printf "template ready to use.\n\n"

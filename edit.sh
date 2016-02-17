#!/bin/sh
set -e
set -u
common_opts="--batch --yes --passphrase-fd 0"
encrypted_file="$1"
echo Passphrase:
read -s passphrase
temp_file="$(mktemp)"
chmod 0600 "$temp_file"
echo "$passphrase" | gpg2 $common_opts --decrypt -o "$temp_file" "$encrypted_file" 
$EDITOR "$temp_file"
echo "$passphrase" | gpg2 $common_opts --symmetric --armor -o "$encrypted_file" "$temp_file"
rm "$temp_file"

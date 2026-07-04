#!/bin/bash
# delete_ftp.sh <username>
set -e
USERNAME="$1"
[ -z "$USERNAME" ] && { echo "usage: delete_ftp.sh <username>"; exit 1; }

if id "$USERNAME" &>/dev/null; then
  userdel "$USERNAME"
fi
sed -i "/^${USERNAME}$/d" /etc/vsftpd.userlist 2>/dev/null || true
systemctl restart vsftpd
echo "ftp account ${USERNAME} removed (домашняя папка не удалена автоматически)"

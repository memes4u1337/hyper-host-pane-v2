#!/bin/bash
# create_ftp.sh <username> <password> <home_dir>
set -e
USERNAME="$1"
PASSWORD="$2"
HOMEDIR="$3"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$HOMEDIR" ]; then
  echo "usage: create_ftp.sh <username> <password> <home_dir>"
  exit 1
fi

mkdir -p "$HOMEDIR"

if id "$USERNAME" &>/dev/null; then
  echo "user ${USERNAME} already exists, updating password/home"
  usermod -d "$HOMEDIR" "$USERNAME"
else
  useradd -d "$HOMEDIR" -s /usr/sbin/nologin "$USERNAME"
fi

echo "${USERNAME}:${PASSWORD}" | chpasswd

# chroot-структура для vsftpd: сам HOMEDIR должен принадлежать root и быть без прав записи,
# а реальная папка для загрузки файлов — подпапка внутри.
chown root:root "$HOMEDIR"
chmod 755 "$HOMEDIR"
mkdir -p "$HOMEDIR/files"
chown "$USERNAME":"$USERNAME" "$HOMEDIR/files"

# добавляем пользователя в список разрешённых для vsftpd (userlist_enable=YES, userlist_deny=NO)
touch /etc/vsftpd.userlist
grep -qxF "$USERNAME" /etc/vsftpd.userlist || echo "$USERNAME" >> /etc/vsftpd.userlist

systemctl restart vsftpd
echo "ftp account ${USERNAME} created, upload dir: ${HOMEDIR}/files"

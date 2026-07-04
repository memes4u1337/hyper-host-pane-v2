# Hyper-Host

Собственная панель хостинга (MVP): логин, мониторинг сервера, домены (nginx + Let's Encrypt), FTP-аккаунты (vsftpd).

## 1. Удаление HestiaCP (если стояла)

```bash
sudo bash uninstall_hestia.sh
```

Скрипт остановит и удалит Hestia, её nginx/apache/exim/dovecot/vsftpd (если ставились установщиком Hestia),
почистит /usr/local/hestia, /etc/hestia, cron-задачи, iptables-правила.

⚠️ Перед запуском проверь блок `apt-get remove --purge` в скрипте — если на сервере есть
что-то, кроме Hestia (например своя MySQL с базами), закомментируй лишнее.

## 2. Установка Hyper-Host

```bash
git clone <твой-репозиторий> hyper-host
cd hyper-host
sudo bash install.sh
```

Скрипт спросит логин/пароль администратора панели, поставит nginx, vsftpd, certbot,
python-окружение, systemd-сервис и nginx-конфиг для домена `hyper-host.pw`.

## 3. Привязка домена

1. В DNS-панели регистратора hyper-host.pw создай A-запись на IP этого сервера:
   ```
   hyper-host.pw   A   <IP сервера>
   www             A   <IP сервера>
   ```
2. Подожди обновления DNS (проверка: `dig +short hyper-host.pw`).
3. Выпусти SSL:
   ```bash
   sudo certbot --nginx -d hyper-host.pw -d www.hyper-host.pw
   ```

После этого панель будет доступна по `https://hyper-host.pw`.

## 4. Что умеет панель сейчас

- Логин по логину/паролю (хранится в sqlite, пароль хэшируется)
- Дашборд: CPU, RAM, диск, uptime, load average
- Домены: добавление домена создаёт nginx vhost + папку `/var/www/<domain>/public_html`,
  опционально сразу выпускает SSL
- FTP: создание системного пользователя + запись в vsftpd, chroot в `/home/hh-ftp/<user>/files`

## 5. Как расширять модулями

Каждый раздел — это отдельный blueprint-подобный роут в `app/app.py` + свой шаблон в `app/templates/`
+ (если нужно root-действие) отдельный скрипт в `scripts/`, прописанный в `/etc/sudoers.d/hyper-host`.
Примеры того, что добавить дальше: базы данных MySQL, PHP-FPM пулы под каждый домен,
почта (Postfix/Dovecot), бэкапы, письма/уведомления в Telegram.

## 6. Управление сервисом

```bash
sudo systemctl status hyper-host
sudo systemctl restart hyper-host
sudo journalctl -u hyper-host -f
```

---
Powered by memes4u1337

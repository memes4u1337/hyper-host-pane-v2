import os
import sqlite3
import subprocess
import shutil
import psutil
from datetime import datetime
from functools import wraps
from flask import Flask, render_template, request, redirect, url_for, session, flash, g
from werkzeug.security import generate_password_hash, check_password_hash

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.environ.get("HH_DB", os.path.join(BASE_DIR, "hyperhost.db"))
WEB_ROOT = "/var/www"
FTP_HOME = "/home/hh-ftp"
NGINX_SITES = "/etc/nginx/sites-available"
NGINX_ENABLED = "/etc/nginx/sites-enabled"
SCRIPTS_DIR = os.path.join(os.path.dirname(BASE_DIR), "scripts")

app = Flask(__name__)
app.secret_key = os.environ.get("HH_SECRET", os.urandom(24).hex())

BRAND = "Hyper-Host"
VERSION = "1.0"
DEVELOPER = "memes4u1337"
FOOTER = f"{BRAND} v{VERSION} — Developer: {DEVELOPER}"


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(exception=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    db = sqlite3.connect(DB_PATH)
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS domains (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT UNIQUE NOT NULL,
            docroot TEXT NOT NULL,
            ssl INTEGER DEFAULT 0,
            created_at TEXT
        );
        CREATE TABLE IF NOT EXISTS ftp_accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            home_dir TEXT NOT NULL,
            created_at TEXT
        );
        """
    )
    db.commit()
    db.close()


def login_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not session.get("user_id"):
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return wrapper


def run_root_script(script_name, *args):
    """Запускает вспомогательный shell-скрипт с sudo (панель должна иметь право
    выполнять эти скрипты без пароля — см. install.sh, настройка sudoers)."""
    path = os.path.join(SCRIPTS_DIR, script_name)
    cmd = ["sudo", "/bin/bash", path] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0, (result.stdout + result.stderr)


# ---------- AUTH ----------

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        db = get_db()
        user = db.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
        if user and check_password_hash(user["password_hash"], password):
            session["user_id"] = user["id"]
            session["username"] = user["username"]
            return redirect(url_for("dashboard"))
        flash("Неверный логин или пароль", "error")
    return render_template("login.html", brand=BRAND, footer=FOOTER)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


# ---------- DASHBOARD ----------

@app.route("/")
@login_required
def dashboard():
    cpu = psutil.cpu_percent(interval=0.3)
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    uptime_seconds = int(datetime.now().timestamp() - psutil.boot_time())
    uptime = str(uptime_seconds // 86400) + "д " + str((uptime_seconds % 86400) // 3600) + "ч"
    load1, load5, load15 = os.getloadavg()

    db = get_db()
    domains_count = db.execute("SELECT COUNT(*) c FROM domains").fetchone()["c"]
    ftp_count = db.execute("SELECT COUNT(*) c FROM ftp_accounts").fetchone()["c"]

    return render_template(
        "dashboard.html",
        brand=BRAND,
        footer=FOOTER,
        cpu=cpu,
        mem=mem,
        disk=disk,
        uptime=uptime,
        load=(load1, load5, load15),
        domains_count=domains_count,
        ftp_count=ftp_count,
    )


# ---------- DOMAINS ----------

@app.route("/domains", methods=["GET", "POST"])
@login_required
def domains():
    db = get_db()
    if request.method == "POST":
        domain = request.form.get("domain", "").strip().lower()
        want_ssl = request.form.get("ssl") == "on"
        if not domain:
            flash("Укажи домен", "error")
            return redirect(url_for("domains"))

        docroot = os.path.join(WEB_ROOT, domain, "public_html")
        ok, out = run_root_script("create_domain.sh", domain, docroot)
        if not ok:
            flash(f"Ошибка создания домена: {out}", "error")
            return redirect(url_for("domains"))

        ssl_ok = True
        if want_ssl:
            ssl_ok, out2 = run_root_script("issue_ssl.sh", domain)
            if not ssl_ok:
                flash(f"Домен создан, но SSL не выпустился (проверь, что DNS домена уже указывает на этот сервер): {out2}", "error")

        db.execute(
            "INSERT OR REPLACE INTO domains (domain, docroot, ssl, created_at) VALUES (?,?,?,?)",
            (domain, docroot, 1 if (want_ssl and ssl_ok) else 0, datetime.now().isoformat()),
        )
        db.commit()
        flash(f"Домен {domain} добавлен", "success")
        return redirect(url_for("domains"))

    rows = db.execute("SELECT * FROM domains ORDER BY id DESC").fetchall()
    return render_template("domains.html", brand=BRAND, footer=FOOTER, domains=rows)


@app.route("/domains/delete/<int:domain_id>", methods=["POST"])
@login_required
def delete_domain(domain_id):
    db = get_db()
    row = db.execute("SELECT * FROM domains WHERE id=?", (domain_id,)).fetchone()
    if row:
        run_root_script("delete_domain.sh", row["domain"])
        db.execute("DELETE FROM domains WHERE id=?", (domain_id,))
        db.commit()
        flash(f"Домен {row['domain']} удалён", "success")
    return redirect(url_for("domains"))


# ---------- FTP ----------

@app.route("/ftp", methods=["GET", "POST"])
@login_required
def ftp_accounts():
    db = get_db()
    if request.method == "POST":
        username = request.form.get("username", "").strip().lower()
        password = request.form.get("password", "")
        if not username or not password:
            flash("Укажи логин и пароль", "error")
            return redirect(url_for("ftp_accounts"))

        home_dir = os.path.join(FTP_HOME, username)
        ok, out = run_root_script("create_ftp.sh", username, password, home_dir)
        if not ok:
            flash(f"Ошибка создания FTP-аккаунта: {out}", "error")
            return redirect(url_for("ftp_accounts"))

        db.execute(
            "INSERT OR REPLACE INTO ftp_accounts (username, home_dir, created_at) VALUES (?,?,?)",
            (username, home_dir, datetime.now().isoformat()),
        )
        db.commit()
        flash(f"FTP-аккаунт {username} создан", "success")
        return redirect(url_for("ftp_accounts"))

    rows = db.execute("SELECT * FROM ftp_accounts ORDER BY id DESC").fetchall()
    return render_template("ftp.html", brand=BRAND, footer=FOOTER, accounts=rows)


@app.route("/ftp/delete/<int:account_id>", methods=["POST"])
@login_required
def delete_ftp(account_id):
    db = get_db()
    row = db.execute("SELECT * FROM ftp_accounts WHERE id=?", (account_id,)).fetchone()
    if row:
        run_root_script("delete_ftp.sh", row["username"])
        db.execute("DELETE FROM ftp_accounts WHERE id=?", (account_id,))
        db.commit()
        flash(f"FTP-аккаунт {row['username']} удалён", "success")
    return redirect(url_for("ftp_accounts"))


if __name__ == "__main__":
    if not os.path.exists(DB_PATH):
        init_db()
    app.run(host="127.0.0.1", port=8088)

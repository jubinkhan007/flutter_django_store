#!/bin/bash

# ==============================================================================
# CodeCanyon Product: ShopEase E-Commerce Platform
# Interactive Deployment Script for Ubuntu 22.04+
# Stack: PostgreSQL, Redis, Django, Gunicorn, Celery, Nginx
# ==============================================================================

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}             Welcome to the ShopEase One-Click Installer!                     ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "This script will completely configure your server, database, and backend APIs."
echo ""

# 1. Interactive Prompts
read -p "Enter your live Domain Name (e.g., api.mystore.com): " APP_DOMAIN
read -p "Enter a new PostgreSQL Username: " DB_USER
read -s -p "Enter a secure PostgreSQL Password: " DB_PASS
echo ""
read -p "Enter a strong Django Secret Key (leave empty to auto-generate): " SECRET_KEY

if [ -z "$SECRET_KEY" ]; then
    SECRET_KEY=$(tr -dc 'a-zA-Z0-9!@#$%^&*' < /dev/urandom | head -c 50)
    echo -e "${YELLOW}Auto-generated Django Secret Key.${NC}"
fi

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$APP_DIR/venv"
CURRENT_USER=$(whoami)

echo -e "\n${BLUE}[1/8] Updating System & Installing Dependencies...${NC}"
sudo apt update
sudo apt install -y python3 python3-venv python3-dev postgresql postgresql-contrib redis-server \
    nginx supervisor certbot python3-certbot-nginx libpq-dev curl git

echo -e "\n${BLUE}[2/8] Setting up PostgreSQL...${NC}"
sudo systemctl start postgresql
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ecommerce_db;" || true
sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" || true
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "CREATE DATABASE ecommerce_db OWNER $DB_USER;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ecommerce_db TO $DB_USER;"

echo -e "\n${BLUE}[3/8] Generating .env Configuration File...${NC}"
cat <<EOF > $APP_DIR/.env
SECRET_KEY=$SECRET_KEY
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,$APP_DOMAIN

DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost:5432/ecommerce_db
REDIS_URL=redis://127.0.0.1:6379/1

# SSL & Security
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
CORS_ALLOW_ALL_ORIGINS=True
EOF
echo -e "${GREEN}.env file successfully generated!${NC}"

echo -e "\n${BLUE}[4/8] Setting up Python Virtual Environment...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
fi

$VENV_DIR/bin/python -m pip install --upgrade pip
$VENV_DIR/bin/pip install -r $APP_DIR/requirements.txt

echo -e "\n${BLUE}[5/8] Running Database Migrations & Static Files...${NC}"
$VENV_DIR/bin/python $APP_DIR/manage.py migrate
$VENV_DIR/bin/python $APP_DIR/manage.py collectstatic --noinput

echo -e "\n${BLUE}[6/8] Configuring Nginx Web Server...${NC}"
sudo chmod 755 /root || true # Ensure Nginx can read the directory if installed in root
sudo chmod 755 /root/* || true

# Rename the template to match the domain
cat $APP_DIR/deploy/nginx/shopease.conf > /tmp/app_nginx.conf
sed -i "s|shopease.chickenkiller.com|$APP_DOMAIN|g" /tmp/app_nginx.conf
sed -i "s|/var/www/ecommerce|$APP_DIR|g" /tmp/app_nginx.conf

sudo mv /tmp/app_nginx.conf /etc/nginx/sites-available/$APP_DOMAIN.conf
sudo ln -sf /etc/nginx/sites-available/$APP_DOMAIN.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl restart nginx

echo -e "\n${BLUE}[7/8] Configuring Gunicorn and Celery Workers...${NC}"
sudo mkdir -p /var/log/gunicorn /var/log/celery
sudo chown $CURRENT_USER:$CURRENT_USER /var/log/gunicorn /var/log/celery

cat $APP_DIR/deploy/supervisor/ecommerce.conf > /tmp/app_supervisor.conf
sed -i "s|/var/www/ecommerce|$APP_DIR|g" /tmp/app_supervisor.conf
sed -i "s|user=ubuntu|user=$CURRENT_USER|g" /tmp/app_supervisor.conf
# Fix line continuity issue
sed -i ':a;N;$!ba;s/\\\n *//g' /tmp/app_supervisor.conf

sudo mv /tmp/app_supervisor.conf /etc/supervisor/conf.d/ecommerce.conf
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl restart all

echo -e "\n${BLUE}[8/8] Enabling Firewall...${NC}"
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw --force enable

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN} Deployment Successful! ${NC}"
echo -e " Your backend is now running at: http://$APP_DOMAIN"
echo -e ""
echo -e " ${YELLOW}IMPORTANT: To secure your server with HTTPS, ensure your domain's DNS${NC}"
echo -e " ${YELLOW}A-record points to this server's IP, then run:${NC}"
echo -e " sudo certbot --nginx -d $APP_DOMAIN"
echo -e "\n Optionally, to generate beautiful Demo Data, run:"
echo -e " $VENV_DIR/bin/python $APP_DIR/manage.py seed_demo_data"
echo -e "${GREEN}==============================================================================${NC}"

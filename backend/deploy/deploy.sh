#!/bin/bash

# ecommerce_app Deployment Script for Ubuntu 22.04 (Contabo)
# Domain: shopease.chickenkiller.com

set -e

# Automatically detect the directory (assumes script is in deploy/ folder inside backend)
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$APP_DIR/venv"
CURRENT_USER=$(whoami)

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y python3.12 python3.12-venv python3.12-dev postgresql postgresql-contrib redis-server nginx supervisor certbot python3-certbot-nginx libpq-dev curl git

echo "Setting up Database..."
# Note: This assumes the user will provide DB credentials or let us generate them
# In a real scenario, we'd prompt or use a .env file.
# For now, we plan for 'ecommerce_db' with user 'ecommerce_user'

echo "Creating App Directory..."
mkdir -p $APP_DIR
# (Here the user would git clone or we would transfer files)

echo "Setting up Virtual Environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3.12 -m venv $VENV_DIR
fi

source $VENV_DIR/bin/activate
pip install --upgrade pip
pip install -r $APP_DIR/requirements.txt

echo "Preparing Static Files..."
mkdir -p $APP_DIR/staticfiles
python $APP_DIR/manage.py collectstatic --noinput

echo "Running Migrations..."
python $APP_DIR/manage.py migrate

echo "Configuring Nginx..."
sudo cp $APP_DIR/deploy/nginx/shopease.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/shopease.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "Configuring Supervisor..."
sudo mkdir -p /var/log/gunicorn /var/log/celery
sudo chown $CURRENT_USER:$CURRENT_USER /var/log/gunicorn /var/log/celery
sudo cp $APP_DIR/deploy/supervisor/ecommerce.conf /etc/supervisor/conf.d/
sudo sed -i "s|/home/ubuntu/ecommerce_app/backend|$APP_DIR|g" /etc/supervisor/conf.d/ecommerce.conf
sudo sed -i "s|user=ubuntu|user=$CURRENT_USER|g" /etc/supervisor/conf.d/ecommerce.conf
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl restart all

echo "Enabling Firewall..."
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw --force enable

echo "Ready for SSL. Run: sudo certbot --nginx -d shopease.chickenkiller.com"

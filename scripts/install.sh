#!/bin/bash

# Basic check
if [[ $EUID -ne 0 ]]; then
   echo "Run as root (use sudo)"
   exit 1
fi

echo "[1/6] Installing dependencies..."
apt update && apt install -y python3 python3-pip nginx hostapd dnsmasq git unzip

echo "[2/6] Setting up Wi-Fi config..."
cp wifi-ap-config/hostapd.conf /etc/hostapd/
cp wifi-ap-config/dnsmasq.conf /etc/dnsmasq.conf

echo "[3/6] Enabling Wi-Fi services..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq

echo "[4/6] Setting up Flask backend..."
pip3 install -r backend/requirements.txt
cp systemd/offgridnet.service /etc/systemd/system/
systemctl enable offgridnet.service

echo "[5/6] Enabling Kiwix..."
cp systemd/kiwix.service /etc/systemd/system/
systemctl enable kiwix.service

echo "[6/6] Deploying frontend..."
cp frontend/index.html /var/www/html/index.html

echo "Setup complete! Rebooting in 5 seconds..."
sleep 5 && reboot 
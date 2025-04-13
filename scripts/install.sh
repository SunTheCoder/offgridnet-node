#!/bin/bash

# Basic check
if [[ $EUID -ne 0 ]]; then
   echo "Run as root (use sudo)"
   exit 1
fi

# Function to check if a command succeeded
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed"
        exit 1
    fi
}

echo "[1/6] Installing dependencies..."
apt update && apt install -y python3 python3-pip nginx hostapd dnsmasq git unzip
check_status "Dependency installation"

echo "[2/6] Setting up Wi-Fi config..."
cp wifi-ap-config/hostapd.conf /etc/hostapd/
cp wifi-ap-config/dnsmasq.conf /etc/dnsmasq.conf
check_status "Wi-Fi configuration"

echo "[3/6] Enabling Wi-Fi services..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
check_status "Wi-Fi services setup"

echo "[4/6] Setting up Flask backend..."
# Create necessary directories
mkdir -p /home/sunny/offgridnet-node/backend
chown -R sunny:sunny /home/sunny/offgridnet-node

# Install Python dependencies
pip3 install -r backend/requirements.txt
check_status "Python dependencies installation"

# Copy and set up systemd service
cp systemd/offgridnet.service /etc/systemd/system/
chmod 644 /etc/systemd/system/offgridnet.service

# Create log directory and set permissions
mkdir -p /var/log/offgridnet
chown sunny:sunny /var/log/offgridnet

# Enable and start the service
systemctl daemon-reload
systemctl enable offgridnet.service
systemctl start offgridnet.service

# Check if service started successfully
if ! systemctl is-active --quiet offgridnet.service; then
    echo "Error: Flask backend failed to start"
    echo "Checking logs..."
    journalctl -u offgridnet.service -n 50
    exit 1
fi

echo "[5/6] Enabling Kiwix..."
# Create Kiwix directory
mkdir -p /home/sunny/kiwix/data
chown -R sunny:sunny /home/sunny/kiwix

cp systemd/kiwix.service /etc/systemd/system/
systemctl enable kiwix.service
check_status "Kiwix setup"

echo "[6/6] Deploying frontend..."
cp frontend/index.html /var/www/html/index.html
check_status "Frontend deployment"

echo "Setup complete! Checking service status..."
systemctl status offgridnet.service
systemctl status kiwix.service

echo "Rebooting in 5 seconds..."
sleep 5 && reboot 
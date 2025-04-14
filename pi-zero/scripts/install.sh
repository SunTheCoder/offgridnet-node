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

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: Required file $1 not found"
        exit 1
    fi
}

echo "[1/4] Installing dependencies..."
# Install required packages
apt update && apt install -y python3 python3-pip python3-venv nginx hostapd dnsmasq git unzip
check_status "Dependency installation"

echo "[2/4] Setting up Wi-Fi config..."
# Unblock WiFi if it's blocked by rfkill
rfkill unblock wifi
sleep 2

# Stop any existing WiFi services
systemctl stop wpa_supplicant
systemctl disable wpa_supplicant

# Configure static IP for wlan0
cat >> /etc/dhcpcd.conf << EOF

# OffGridNet Access Point Configuration
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

# Verify and copy configuration files
check_file "wifi-ap-config/hostapd.conf"
check_file "wifi-ap-config/dnsmasq.conf"
cp wifi-ap-config/hostapd.conf /etc/hostapd/
cp wifi-ap-config/dnsmasq.conf /etc/dnsmasq.conf

# Update hostapd configuration
sed -i 's/^#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/default/hostapd

# Set up dhcpcd service
check_file "systemd/dhcpcd.service"
cp systemd/dhcpcd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable dhcpcd
systemctl start dhcpcd

# Set up hostapd service
check_file "systemd/hostapd.service"
cp systemd/hostapd.service /etc/systemd/system/
systemctl daemon-reload
systemctl unmask hostapd
systemctl enable hostapd
systemctl stop hostapd
sleep 2
systemctl start hostapd

# Enable dnsmasq
systemctl enable dnsmasq
systemctl stop dnsmasq
sleep 2
systemctl start dnsmasq
check_status "Wi-Fi configuration"

echo "[3/4] Setting up Flask backend..."
# Create necessary directories
mkdir -p /home/sunny/offgridnet-node/backend
chown -R sunny:sunny /home/sunny/offgridnet-node

# Copy backend files
check_file "../common/backend/requirements.txt"
cp -r ../common/backend/* /home/sunny/offgridnet-node/backend/

# Create and activate virtual environment
su - sunny -c "cd /home/sunny/offgridnet-node/backend && python3 -m venv venv"
su - sunny -c "cd /home/sunny/offgridnet-node/backend && source venv/bin/activate && pip install --upgrade pip"
su - sunny -c "cd /home/sunny/offgridnet-node/backend && source venv/bin/activate && pip install -r requirements.txt"

# Copy and set up systemd service
check_file "systemd/offgridnet.service"
cp systemd/offgridnet.service /etc/systemd/system/
chmod 644 /etc/systemd/system/offgridnet.service
systemctl enable offgridnet.service

# Create log directory
mkdir -p /var/log/offgridnet
chown sunny:sunny /var/log/offgridnet

echo "[4/4] Setting up Kiwix..."
# Create Kiwix directory
mkdir -p /home/sunny/kiwix/data
chown -R sunny:sunny /home/sunny/kiwix

# Copy Kiwix service
check_file "systemd/kiwix.service"
cp systemd/kiwix.service /etc/systemd/system/
systemctl enable kiwix.service

# Deploy frontend
check_file "../common/frontend/index.html"
mkdir -p /var/www/html
cp ../common/frontend/index.html /var/www/html/

echo "Setup complete! All services will start automatically on boot."
echo "Access point will be available as 'OffGridNet' with password 'Datathug2024!'"
echo "Rebooting in 5 seconds..."
sleep 5 && reboot 
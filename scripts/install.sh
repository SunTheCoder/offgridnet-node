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
# Install dhcpcd5 with non-interactive mode to keep existing config
DEBIAN_FRONTEND=noninteractive apt-get install -y dhcpcd5
apt update && apt install -y python3 python3-pip python3-venv nginx hostapd dnsmasq git unzip
check_status "Dependency installation"

echo "[2/6] Setting up Wi-Fi config..."
# Unblock WiFi if it's blocked by rfkill
rfkill unblock wifi
sleep 2

# Stop any existing WiFi services
systemctl stop wpa_supplicant
systemctl disable wpa_supplicant

# Append OffGridNet configuration to dhcpcd.conf
cat >> /etc/dhcpcd.conf << EOF

# OffGridNet Access Point Configuration
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

# Copy configuration files
cp wifi-ap-config/hostapd.conf /etc/hostapd/
cp wifi-ap-config/dnsmasq.conf /etc/dnsmasq.conf

# Update hostapd configuration
sed -i 's/^#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/default/hostapd
check_status "Wi-Fi configuration"

echo "[3/6] Enabling Wi-Fi services..."
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl enable dhcpcd
check_status "Wi-Fi services setup"

echo "[4/6] Setting up Flask backend..."
# Create necessary directories
mkdir -p /home/sunny/offgridnet-node/backend
chown -R sunny:sunny /home/sunny/offgridnet-node

# Create and activate virtual environment
su - sunny -c "cd /home/sunny/offgridnet-node/backend && python3 -m venv venv"
su - sunny -c "cd /home/sunny/offgridnet-node/backend && source venv/bin/activate && pip install --upgrade pip"
su - sunny -c "cd /home/sunny/offgridnet-node/backend && source venv/bin/activate && pip install -r requirements.txt"
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

echo "Verifying access point configuration..."
# Restart network services
systemctl restart dhcpcd
systemctl restart hostapd
systemctl restart dnsmasq

# Check if wlan0 is up
if ! ip link show wlan0 | grep -q "state UP"; then
    echo "Bringing up wlan0 interface..."
    ip link set wlan0 up
    sleep 2
fi

# Check if hostapd is running
if ! systemctl is-active --quiet hostapd; then
    echo "Starting hostapd service..."
    systemctl start hostapd
    sleep 2
fi

# Verify WiFi is unblocked
if rfkill list wifi | grep -q "Soft blocked: yes"; then
    echo "WiFi is still soft blocked, trying to unblock..."
    rfkill unblock wifi
    sleep 2
fi

echo "Setup complete! Checking service status..."
systemctl status offgridnet.service
systemctl status kiwix.service
systemctl status hostapd
systemctl status dhcpcd

echo "Access point should be available as 'OffGridNet' with password 'Datathug2024!'"
echo "Rebooting in 5 seconds..."
sleep 5 && reboot 
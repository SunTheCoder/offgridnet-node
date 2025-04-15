#!/bin/bash

# Create log file
LOG_FILE="/var/log/offgridnet-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== OffGridNet Installation Started at $(date) ==="

# Basic check
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)"
   exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PI_ZERO_DIR="$(dirname "$SCRIPT_DIR")"

# Function to check if a command succeeded
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed"
        exit 1
    fi
    echo "Success: $1 completed"
}

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: Required file $1 not found"
        exit 1
    fi
    echo "Found file: $1"
}

echo "[1/4] Installing dependencies..."
echo "Updating package list..."
apt update
echo "Installing required packages..."
apt install -y python3 python3-pip python3-venv nginx hostapd dnsmasq git unzip
check_status "Dependency installation"

echo "[2/4] Setting up Wi-Fi config..."
echo "Current WiFi status:"
rfkill list
echo "Unblocking WiFi..."
rfkill unblock wifi
sleep 2
echo "WiFi status after unblocking:"
rfkill list

# Disable dhcpcd
echo "Disabling dhcpcd..."
systemctl stop dhcpcd
systemctl disable dhcpcd
echo "dhcpcd status:"
systemctl status dhcpcd

# Configure static IP for wlan0
echo "Configuring static IP..."
cat > /etc/network/interfaces.d/wlan0 << EOF
auto wlan0
iface wlan0 inet static
    address 192.168.4.1
    netmask 255.255.255.0
    network 192.168.4.0
    broadcast 192.168.4.255
EOF

# Copy configuration files
echo "Copying configuration files..."
check_file "$PI_ZERO_DIR/wifi-ap-config/hostapd.conf"
check_file "$PI_ZERO_DIR/wifi-ap-config/dnsmasq.conf"
cp "$PI_ZERO_DIR/wifi-ap-config/hostapd.conf" /etc/hostapd/
cp "$PI_ZERO_DIR/wifi-ap-config/dnsmasq.conf" /etc/dnsmasq.conf

# Update hostapd configuration
echo "Updating hostapd configuration..."
sed -i 's/^#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/default/hostapd

# Create hostapd PID directory
echo "Creating hostapd PID directory..."
mkdir -p /run/hostapd
chown root:root /run/hostapd
chmod 755 /run/hostapd

# Bring up the interface properly
echo "Bringing up wlan0 interface..."
ip link set wlan0 down
sleep 2
ip link set wlan0 up
sleep 2
ip addr flush dev wlan0
ip addr add 192.168.4.1/24 broadcast 192.168.4.255 dev wlan0
echo "Interface status:"
ip link show wlan0
ip addr show wlan0

# Set up hostapd service
echo "Setting up hostapd service..."
check_file "$PI_ZERO_DIR/systemd/hostapd.service"
cp "$PI_ZERO_DIR/systemd/hostapd.service" /etc/systemd/system/
systemctl daemon-reload
systemctl unmask hostapd
systemctl enable hostapd
systemctl stop hostapd
sleep 2
systemctl start hostapd
echo "hostapd service status:"
systemctl status hostapd

# Enable dnsmasq
echo "Setting up dnsmasq..."
systemctl enable dnsmasq
systemctl stop dnsmasq
sleep 2
systemctl start dnsmasq
echo "dnsmasq service status:"
systemctl status dnsmasq

echo "Checking wlan0 status..."
echo "=== wlan0 Link Status ==="
ip link show wlan0
echo "=== wlan0 Wireless Info ==="
iw dev wlan0 info
echo "=== wlan0 IP Configuration ==="
ip addr show wlan0
echo "=== WiFi Block Status ==="
rfkill list

check_status "Wi-Fi configuration"

echo "[3/4] Setting up Flask backend..."
echo "Creating backend directories..."
mkdir -p /home/sunny/offgridnet-node/backend
chown -R sunny:sunny /home/sunny/offgridnet-node

echo "Copying backend files..."
check_file "$PI_ZERO_DIR/../common/backend/requirements.txt"
cp -r "$PI_ZERO_DIR/../common/backend/"* /home/sunny/offgridnet-node/backend/

echo "Setting up Python virtual environment..."
su - sunny -c "cd /home/sunny/offgridnet-node/backend && python3 -m venv venv"
su - sunny -c "cd /home/sunny/offgridnet-node/backend && source venv/bin/activate && pip install --upgrade pip"
su - sunny -c "cd /home/sunny/offgridnet-node/backend && source venv/bin/activate && pip install -r requirements.txt"

echo "Setting up offgridnet service..."
check_file "$PI_ZERO_DIR/systemd/offgridnet.service"
cp "$PI_ZERO_DIR/systemd/offgridnet.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/offgridnet.service
systemctl enable offgridnet.service
echo "offgridnet service status:"
systemctl status offgridnet.service

echo "Creating log directory..."
mkdir -p /var/log/offgridnet
chown sunny:sunny /var/log/offgridnet

echo "[4/4] Setting up Kiwix..."
echo "Creating Kiwix directories..."
mkdir -p /home/sunny/kiwix/data
chown -R sunny:sunny /home/sunny/kiwix

echo "Setting up Kiwix service..."
check_file "$PI_ZERO_DIR/systemd/kiwix.service"
cp "$PI_ZERO_DIR/systemd/kiwix.service" /etc/systemd/system/
systemctl enable kiwix.service
echo "Kiwix service status:"
systemctl status kiwix.service

echo "Deploying frontend..."
check_file "$PI_ZERO_DIR/../common/frontend/index.html"
mkdir -p /var/www/html
cp "$PI_ZERO_DIR/../common/frontend/index.html" /var/www/html/

echo "=== Final System Status ==="
echo "All services status:"
systemctl status hostapd.service dnsmasq.service offgridnet.service kiwix.service

echo "Network interfaces:"
ip a

echo "WiFi status:"
rfkill list
iw dev

echo "Setup complete! All services will start automatically on boot."
echo "Access point will be available as 'OffGridNet' with password 'Datathug2024!'"
echo "Installation log saved to: $LOG_FILE"

echo "Rebooting in 5 seconds..."
sleep 5 && reboot 
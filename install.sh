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

# Copy configuration files
cp wifi-ap-config/hostapd.conf /etc/hostapd/
cp wifi-ap-config/dnsmasq.conf /etc/dnsmasq.conf

# Update hostapd configuration
sed -i 's/^#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/default/hostapd

echo "[3/4] Setting up Flask backend..."
# Create necessary directories
mkdir -p /home/sunny/offgridnet-node/backend
chown -R sunny:sunny /home/sunny/offgridnet-node

# Create and activate virtual environment
su - sunny -c "cd /home/sunny/offgridnet-node/backend && python3 -m venv venv"
su - sunny -c "cd /home/sunny/offgridnet-node/backend && source venv/bin/activate && pip install --upgrade pip"
su - sunny -c "cd /home/sunny/offgridnet-node/backend && source venv/bin/activate && pip install -r requirements.txt"

# Create log directory
mkdir -p /var/log/offgridnet
chown sunny:sunny /var/log/offgridnet
chmod 755 /var/log/offgridnet

echo "[4/4] Setting up services..."
# Copy systemd service files
cp systemd/hostapd.service /etc/systemd/system/
cp systemd/dnsmasq.service /etc/systemd/system/
cp systemd/set-wlan-ip.service /etc/systemd/system/
cp systemd/offgridnet.service /etc/systemd/system/

# Enable services
systemctl enable set-wlan-ip.service
systemctl enable hostapd.service
systemctl enable dnsmasq.service
systemctl enable offgridnet.service

# Start services in correct order and check status
echo "Starting services..."

start_service() {
    local service=$1
    echo "Starting $service..."
    if ! systemctl start "$service"; then
        echo "Error: Failed to start $service"
        systemctl status "$service"
        exit 1
    fi
    echo "Checking $service status..."
    if ! systemctl is-active --quiet "$service"; then
        echo "Error: $service is not running"
        systemctl status "$service"
        exit 1
    fi
    echo "$service started successfully"
}

start_service "set-wlan-ip.service"
start_service "hostapd.service"
start_service "dnsmasq.service"
start_service "offgridnet.service"

echo "Setting up Kiwix..."
# Install kiwix-tools
apt install -y kiwix-tools
check_status "Kiwix installation"

# Create Kiwix directory and set permissions
mkdir -p /home/sunny/kiwix/data
chown -R sunny:sunny /home/sunny/kiwix
chmod 755 /home/sunny/kiwix

# Stop any existing Kiwix process
pkill kiwix-serve || true
sleep 2

# Download Nollywood Wikipedia ZIM file
echo "Downloading Nollywood Wikipedia ZIM file..."
su - sunny -c "cd /home/sunny/kiwix/data && wget --no-check-certificate https://download.kiwix.org/zim/wikipedia/wikipedia_en_nollywood_maxi_2025-04.zim"
check_status "ZIM file download"

# Verify ZIM file exists and has content
if [ ! -f "/home/sunny/kiwix/data/wikipedia_en_nollywood_maxi_2025-04.zim" ]; then
    echo "Error: ZIM file download failed - file not found"
    exit 1
fi

ZIM_SIZE=$(stat -c%s "/home/sunny/kiwix/data/wikipedia_en_nollywood_maxi_2025-04.zim")
if [ "$ZIM_SIZE" -lt 1000000 ]; then
    echo "Error: ZIM file appears to be too small or corrupted"
    exit 1
fi

# Create library.xml
echo "Creating Kiwix library..."
su - sunny -c "cd /home/sunny/kiwix/data && kiwix-manage library.xml add wikipedia_en_nollywood_maxi_2025-04.zim"
check_status "Library creation"

# Verify library.xml exists
if [ ! -f "/home/sunny/kiwix/data/library.xml" ]; then
    echo "Error: library.xml creation failed"
    exit 1
fi

# Copy and enable Kiwix service
cp systemd/kiwix.service /etc/systemd/system/
chmod 644 /etc/systemd/system/kiwix.service
systemctl daemon-reload
systemctl enable kiwix.service

# Start Kiwix service
start_service "kiwix.service"

# Create a startup script to ensure Kiwix starts after network is up
cat > /etc/network/if-up.d/start-kiwix << 'EOF'
#!/bin/sh
if [ "$IFACE" = "wlan0" ]; then
    sleep 5
    systemctl start kiwix.service
fi
EOF

chmod +x /etc/network/if-up.d/start-kiwix

# Add debugging information
echo "Kiwix setup complete. Debug information:"
echo "ZIM file location: /home/sunny/kiwix/data/wikipedia_en_nollywood_maxi_2025-04.zim"
echo "ZIM file size: $(du -h /home/sunny/kiwix/data/wikipedia_en_nollywood_maxi_2025-04.zim | cut -f1)"
echo "Library file: /home/sunny/kiwix/data/library.xml"
echo "Service status:"
systemctl status kiwix.service
echo "Access Kiwix at http://192.168.4.1:8080" 
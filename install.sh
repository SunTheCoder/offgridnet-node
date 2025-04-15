# Create necessary directories
echo "Creating directories..."
mkdir -p /var/log/offgridnet
mkdir -p /home/sunny/kiwix/data

# Set permissions
echo "Setting permissions..."
chown -R sunny:sunny /var/log/offgridnet
chown -R sunny:sunny /home/sunny/kiwix
chown -R sunny:sunny /var/www/html

# Install Kiwix and dependencies
echo "Installing Kiwix and dependencies..."
apt update
apt install -y kiwix-tools wget

# Verify Kiwix installation
echo "Verifying Kiwix installation..."
if [ ! -f "/usr/bin/kiwix-serve" ]; then
    echo "Error: kiwix-serve not found at /usr/bin/kiwix-serve"
    echo "Trying to find kiwix-serve..."
    find / -name kiwix-serve 2>/dev/null
    exit 1
fi

# Allow port 8080 through firewall
echo "Configuring firewall..."
ufw allow 8080/tcp

# Download ZIM file from Kiwix
echo "Downloading ZIM file..."
cd /home/sunny/kiwix/data
wget https://download.kiwix.org/zim/wikipedia/wikipedia_en_nollywood_maxi_2025-04.zim
chown sunny:sunny wikipedia_en_nollywood_maxi_2025-04.zim

# Generate library.xml
echo "Generating Kiwix library..."
kiwix-manage /home/sunny/kiwix/data/library.xml add /home/sunny/kiwix/data/wikipedia_en_nollywood_maxi_2025-04.zim
chown sunny:sunny /home/sunny/kiwix/data/library.xml

# Copy systemd service files
echo "Copying systemd service files..."
cp systemd/hostapd.service /etc/systemd/system/
cp systemd/dnsmasq.service /etc/systemd/system/
cp systemd/kiwix.service /etc/systemd/system/
cp systemd/set-wlan-ip.service /etc/systemd/system/
cp systemd/offgridnet.service /etc/systemd/system/

# Enable and start services in correct order
echo "Enabling and starting services..."
systemctl enable set-wlan-ip.service
systemctl enable hostapd.service
systemctl enable dnsmasq.service
systemctl enable kiwix.service
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
start_service "kiwix.service"
start_service "offgridnet.service"

echo "All services started successfully" 
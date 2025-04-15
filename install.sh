# Create necessary directories
echo "Creating directories..."
mkdir -p /var/log/offgridnet
mkdir -p /home/sunny/kiwix/data

# Set permissions
echo "Setting permissions..."
chown -R sunny:sunny /var/log/offgridnet
chown -R sunny:sunny /home/sunny/kiwix
chown -R sunny:sunny /var/www/html

# Install Kiwix
echo "Installing Kiwix..."
apt install -y kiwix-tools

# Copy ZIM file to Kiwix data directory
echo "Setting up ZIM file..."
cp wikipedia_en_nollywood_maxi_2025-04.zim /home/sunny/kiwix/data/
chown sunny:sunny /home/sunny/kiwix/data/wikipedia_en_nollywood_maxi_2025-04.zim

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
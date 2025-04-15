# Copy systemd service files
echo "Copying systemd service files..."
cp systemd/hostapd.service /etc/systemd/system/
cp systemd/dnsmasq.service /etc/systemd/system/
cp systemd/kiwix.service /etc/systemd/system/
cp systemd/set-wlan-ip.service /etc/systemd/system/
cp systemd/meshnode.service /etc/systemd/system/

# Enable and start services in correct order
echo "Enabling and starting services..."
systemctl enable set-wlan-ip.service
systemctl enable hostapd.service
systemctl enable dnsmasq.service
systemctl enable kiwix.service
systemctl enable meshnode.service

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
start_service "meshnode.service"

echo "All services started successfully"

echo "[4/4] Setting up Kiwix..."
# Create Kiwix directory and set permissions
mkdir -p /home/sunny/kiwix/data
chown -R sunny:sunny /home/sunny/kiwix
chmod 755 /home/sunny/kiwix

# Create log directory
mkdir -p /var/log/offgridnet
chown sunny:sunny /var/log/offgridnet
chmod 755 /var/log/offgridnet

# Copy service file
cp systemd/kiwix.service /etc/systemd/system/
chmod 644 /etc/systemd/system/kiwix.service

# Enable and start Kiwix
systemctl daemon-reload
systemctl enable kiwix.service
systemctl start kiwix.service

# Check Kiwix status
if ! systemctl is-active --quiet kiwix.service; then
    echo "Error: Kiwix service failed to start"
    systemctl status kiwix.service
    exit 1
fi 
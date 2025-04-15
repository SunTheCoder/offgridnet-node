# Copy systemd service files
echo "Copying systemd service files..."
cp systemd/hostapd.service /etc/systemd/system/
cp systemd/dnsmasq.service /etc/systemd/system/
# cp systemd/kiwix.service /etc/systemd/system/
cp systemd/set-wlan-ip.service /etc/systemd/system/
cp systemd/offgridnet.service /etc/systemd/system/

# Enable and start services in correct order
echo "Enabling and starting services..."
systemctl enable set-wlan-ip.service
systemctl enable hostapd.service
systemctl enable dnsmasq.service
# systemctl enable kiwix.service
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
# start_service "kiwix.service"
start_service "offgridnet.service"

echo "All services started successfully"

# Kiwix setup can be done later
echo "Note: Kiwix setup has been skipped. You can set it up later with:"
echo "1. Install kiwix-tools: sudo apt install kiwix-tools"
echo "2. Create directories: sudo mkdir -p /home/sunny/kiwix/data"
echo "3. Set permissions: sudo chown -R sunny:sunny /home/sunny/kiwix"
echo "4. Enable service: sudo systemctl enable kiwix.service"
echo "5. Start service: sudo systemctl start kiwix.service" 
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
services=(
    "set-wlan-ip.service"
    "hostapd.service"
    "dnsmasq.service"
    "kiwix.service"
    "meshnode.service"
)

for service in "${services[@]}"; do
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
done

echo "All services started successfully" 
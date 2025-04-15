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

echo "[4/4] Setting up Kiwix..."
# Install kiwix-tools
apt install -y kiwix-tools
check_status "Kiwix installation"

# Create Kiwix directory and set permissions
mkdir -p /home/sunny/kiwix/data
chown -R sunny:sunny /home/sunny/kiwix
chmod 755 /home/sunny/kiwix

# Create log directory
mkdir -p /var/log/offgridnet
chown sunny:sunny /var/log/offgridnet
chmod 755 /var/log/offgridnet

# Download a sample ZIM file (Wikipedia)
echo "Downloading Simple English Wikipedia ZIM file..."
su - sunny -c "cd /home/sunny/kiwix/data && wget https://download.kiwix.org/zim/wikipedia/wikipedia_en_simple_all_nopic_2024-06.zim"
check_status "ZIM file download"

# Create library.xml
su - sunny -c "cd /home/sunny/kiwix/data && kiwix-manage library.xml add wikipedia_en_simple_all_nopic_2024-06.zim"
check_status "Library creation"

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

echo "Kiwix setup complete! Access at http://192.168.4.1:8080"

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

# Copy and set up systemd service
cp systemd/offgridnet.service /etc/systemd/system/
chmod 644 /etc/systemd/system/offgridnet.service
systemctl daemon-reload
systemctl enable offgridnet.service

# Start the service
systemctl start offgridnet.service

# Check service status
if ! systemctl is-active --quiet offgridnet.service; then
    echo "Error: offgridnet service failed to start"
    systemctl status offgridnet.service
    exit 1
fi 
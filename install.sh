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

# Download ZIM files from Kiwix
echo "Downloading ZIM files..."
cd /home/sunny/kiwix/data
wget https://download.kiwix.org/zim/wikipedia/wikipedia_en_simple_all_nopic_2024-06.zim
wget https://download.kiwix.org/zim/wiktionary/wikem_en_all_maxi_2021-02.zim
wget https://download.kiwix.org/zim/other/zimgit-food-preparation_en_2025-04.zim
wget https://download.kiwix.org/zim/other/zimgit-knots_en_2024-08.zim
wget https://download.kiwix.org/zim/other/zimgit-medicine_en_2024-08.zim
wget https://download.kiwix.org/zim/other/zimgit-post-disaster_en_2024-05.zim
wget https://download.kiwix.org/zim/other/zimgit-water_en_2024-08.zim
chown sunny:sunny wikipedia_en_simple_all_nopic_2024-06.zim
chown sunny:sunny wikem_en_all_maxi_2021-02.zim
chown sunny:sunny zimgit-food-preparation_en_2025-04.zim
chown sunny:sunny zimgit-knots_en_2024-08.zim
chown sunny:sunny zimgit-medicine_en_2024-08.zim
chown sunny:sunny zimgit-post-disaster_en_2024-05.zim
chown sunny:sunny zimgit-water_en_2024-08.zim

# Generate library.xml
echo "Generating Kiwix library..."
kiwix-manage /home/sunny/kiwix/data/library.xml add /home/sunny/kiwix/data/wikipedia_en_simple_all_nopic_2024-06.zim
kiwix-manage /home/sunny/kiwix/data/library.xml add /home/sunny/kiwix/data/wikem_en_all_maxi_2021-02.zim
kiwix-manage /home/sunny/kiwix/data/library.xml add /home/sunny/kiwix/data/zimgit-food-preparation_en_2025-04.zim
kiwix-manage /home/sunny/kiwix/data/library.xml add /home/sunny/kiwix/data/zimgit-knots_en_2024-08.zim
kiwix-manage /home/sunny/kiwix/data/library.xml add /home/sunny/kiwix/data/zimgit-medicine_en_2024-08.zim
kiwix-manage /home/sunny/kiwix/data/library.xml add /home/sunny/kiwix/data/zimgit-post-disaster_en_2024-05.zim
kiwix-manage /home/sunny/kiwix/data/library.xml add /home/sunny/kiwix/data/zimgit-water_en_2024-08.zim
chown sunny:sunny /home/sunny/kiwix/data/library.xml

# Copy systemd service files
echo "Copying systemd service files..."
cp /home/sunny/offgridnet-node/systemd/hostapd.service /etc/systemd/system/
cp /home/sunny/offgridnet-node/systemd/dnsmasq.service /etc/systemd/system/
cp /home/sunny/offgridnet-node/systemd/kiwix.service /etc/systemd/system/
cp /home/sunny/offgridnet-node/systemd/set-wlan-ip.service /etc/systemd/system/
cp /home/sunny/offgridnet-node/systemd/offgridnet.service /etc/systemd/system/

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
    
    # Special check for Kiwix service
    if [ "$service" = "kiwix.service" ]; then
        echo "Verifying Kiwix library..."
        if [ ! -f "/home/sunny/kiwix/data/library.xml" ] || [ ! -r "/home/sunny/kiwix/data/library.xml" ]; then
            echo "Error: Kiwix library.xml not found or not readable"
            exit 1
        fi
    fi
    
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
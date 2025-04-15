# OffGridNet Node

A complete offline mesh system for Raspberry Pi, serving as a Wi-Fi access point with local services.

## Features

- 📡 Wi-Fi Access Point with SSID "OffGridNet"
- 🌐 Flask backend for local services
- 📝 Local journal system
- 🔒 Secure authentication
- 📚 Offline Wikipedia (Simple English)

## Prerequisites

- Raspberry Pi (Tested on Pi Zero and Pi 5)
- Raspberry Pi OS (64-bit)
- Internet connection for initial setup
- MicroSD card (16GB or larger recommended)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/sunthecoder/offgridnet-node.git
   cd offgridnet-node
   ```

2. Make the install script executable:
   ```bash
   chmod +x install.sh
   ```

3. Run the installation script as root:
   ```bash
   sudo ./install.sh
   ```

The script will:
- Install all necessary dependencies
- Configure the Wi-Fi access point
- Set up the Flask backend
- Download and configure offline Wikipedia (Simple English)
- Reboot the system

## Network Configuration

- SSID: OffGridNet
- Password: Datathug2024!
- Static IP: 192.168.4.1
- DHCP Range: 192.168.4.2 - 192.168.4.20

## Services

### Core Services
1. `set-wlan-ip.service`: Configures wireless interface and assigns static IP
2. `hostapd.service`: Manages the Wi-Fi access point
3. `dnsmasq.service`: Provides DHCP services
4. `offgridnet.service`: Runs the Flask backend
5. `kiwix.service`: Serves offline Wikipedia content

### Flask Backend
- Port: 5000
- Features:
  - User authentication
  - Journal system
  - File sharing

### Offline Wikipedia
- Port: 8080
- Content: Wikipedia Simple English (no images)
- Access: http://192.168.4.1:8080

### Web Interface
- Access: http://192.168.4.1
- Features:
  - Links to all services
  - Dark theme
  - Responsive design

## Maintenance

### Starting/Stopping Services
```bash
# Flask backend
sudo systemctl start/stop/restart offgridnet.service

# Wi-Fi access point
sudo systemctl start/stop/restart hostapd

# Offline Wikipedia
sudo systemctl start/stop/restart kiwix.service
```

### Checking Service Status
```bash
# Check wireless interface
iw dev wlan0 info

# Check service status
sudo systemctl status offgridnet.service
sudo systemctl status hostapd
sudo systemctl status kiwix.service
```

## Troubleshooting

1. **Wi-Fi not working**
   - Check interface mode: `iw dev wlan0 info` (should show `type AP`)
   - Check hostapd status: `sudo systemctl status hostapd`
   - Check hostapd logs: `sudo journalctl -u hostapd`

2. **Flask backend issues**
   - Check logs: `sudo journalctl -u offgridnet.service`
   - Verify database: `ls -l backend/offgridnet.db`

3. **Offline Wikipedia issues**
   - Check logs: `sudo journalctl -u kiwix.service`
   - Verify ZIM file: `ls -l /home/sunny/kiwix/data/wikipedia_en_simple_all_nopic_2024-06.zim`
   - Verify library: `ls -l /home/sunny/kiwix/data/library.xml`

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License 

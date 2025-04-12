# OffGridNet Node

A complete offline mesh system for Raspberry Pi 5, serving HTML, Flask, Kiwix, and acting as a Wi-Fi access point.

## Features

- 📡 Wi-Fi Access Point with SSID "OffGridNet"
- 🌐 Flask backend for local services
- 📘 Kiwix server for offline Wikipedia
- 📝 Local journal system
- 📂 File sharing capabilities
- 🔒 Secure authentication

## Prerequisites

- Raspberry Pi 5
- Raspberry Pi OS (64-bit)
- Internet connection for initial setup
- MicroSD card (16GB or larger recommended)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/offgridnet-node.git
   cd offgridnet-node
   ```

2. Make the install script executable:
   ```bash
   chmod +x scripts/install.sh
   ```

3. Run the installation script as root:
   ```bash
   sudo ./scripts/install.sh
   ```

The script will:
- Install all necessary dependencies
- Configure the Wi-Fi access point
- Set up the Flask backend
- Enable Kiwix server
- Deploy the frontend
- Reboot the system

## Network Configuration

- SSID: OffGridNet
- Password: Datathug2024!
- Static IP: 192.168.4.1
- DHCP Range: 192.168.4.2 - 192.168.4.20

## Services

### Flask Backend
- Port: 5000
- Features:
  - User authentication
  - Journal system
  - File sharing

### Kiwix Server
- Port: 8080
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

# Kiwix server
sudo systemctl start/stop/restart kiwix.service

# Wi-Fi access point
sudo systemctl start/stop/restart hostapd
```

### Checking Service Status
```bash
sudo systemctl status offgridnet.service
sudo systemctl status kiwix.service
sudo systemctl status hostapd
```

## Troubleshooting

1. **Wi-Fi not working**
   - Check if hostapd is running: `sudo systemctl status hostapd`
   - Verify configuration: `sudo cat /etc/hostapd/hostapd.conf`

2. **Flask backend issues**
   - Check logs: `sudo journalctl -u offgridnet.service`
   - Verify database: `ls -l backend/offgridnet.db`

3. **Kiwix not accessible**
   - Check if service is running: `sudo systemctl status kiwix.service`
   - Verify library file exists: `ls -l /home/pi/kiwix/data/library.xml`

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

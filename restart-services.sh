#!/bin/bash

# Test comment for git
sudo rfkill unblock wifi
echo "Unblocked wifi"

echo "Restarting OffGridNet services..."

# Stop services in reverse order
echo "Stopping services..."
sudo systemctl stop offgridnet.service
sudo systemctl stop kiwix.service
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

# Small pause to ensure clean stops
sleep 2

# Configure wireless interface
echo "Configuring wireless interface..."
sudo ip link set wlan0 down
sudo ip addr flush dev wlan0
sudo ip link set wlan0 up
sudo ip addr add 192.168.4.1/24 dev wlan0

# Start services in correct order
echo "Starting services..."
sudo systemctl start dnsmasq
sleep 1
sudo systemctl unmask hostapd
sudo systemctl start hostapd
sleep 2  # Give hostapd time to fully start
sudo systemctl start kiwix.service
sudo systemctl start offgridnet.service

# Check status of all services
echo -e "\nChecking service status:"
echo "-------------------------"
echo "Wireless interface status:"
ip addr show wlan0 | grep "inet "
echo -e "\nDNSMasq status:"
sudo systemctl status dnsmasq | grep "Active:"
echo "HostAPD status:"
sudo systemctl status hostapd | grep "Active:"
echo "Kiwix status:"
sudo systemctl status kiwix.service | grep "Active:"
echo "Flask backend status:"
sudo systemctl status offgridnet.service | grep "Active:"

echo -e "\nDone! All services should be running now." 
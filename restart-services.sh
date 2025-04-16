#!/bin/bash

echo "Restarting OffGridNet services..."

# Stop services in reverse order
echo "Stopping services..."
sudo systemctl stop offgridnet.service
sudo systemctl stop kiwix.service
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

# Small pause to ensure clean stops
sleep 2

# Start services in correct order
echo "Starting services..."
sudo systemctl start dnsmasq
sudo systemctl start hostapd
sudo systemctl start kiwix.service
sudo systemctl start offgridnet.service

# Check status of all services
echo -e "\nChecking service status:"
echo "-------------------------"
echo "DNSMasq status:"
sudo systemctl status dnsmasq | grep "Active:"
echo "HostAPD status:"
sudo systemctl status hostapd | grep "Active:"
echo "Kiwix status:"
sudo systemctl status kiwix.service | grep "Active:"
echo "Flask backend status:"
sudo systemctl status offgridnet.service | grep "Active:"

echo -e "\nDone! All services should be running now." 
#!/bin/bash

# Define paths
REPO_ROOT=$(dirname "$(readlink -f "$0")")
REPO_FRONTEND="$REPO_ROOT/frontend"
WEB_ROOT="/var/www/html"

echo "Updating frontend files..."

# Create web root if it doesn't exist
sudo mkdir -p "$WEB_ROOT"

# Copy index.html
sudo cp "$REPO_FRONTEND/index.html" "$WEB_ROOT/index.html"

# Copy static directory
if [ -d "$WEB_ROOT/static" ]; then
    sudo rm -rf "$WEB_ROOT/static"
fi
sudo cp -r "$REPO_FRONTEND/static" "$WEB_ROOT/static"

# Set permissions
sudo chown -R www-data:www-data "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"

echo "Frontend files updated successfully!"
echo "Restarting Flask service..."
sudo systemctl restart offgridnet.service

echo "Done! Changes should be visible now." 
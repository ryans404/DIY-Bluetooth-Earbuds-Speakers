#!/bin/bash
# Optimized Bluetooth Setup for Raspberry Pi 1

set -e

echo "=== Bluetooth Audio Setup ==="

# Install packages
sudo apt-get update
sudo apt-get install -y bluez bluez-alsa-utils alsa-utils

# Create connection script
sudo tee /usr/local/bin/bt-connect.sh > /dev/null << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/bt-connect.log"
MAX_RETRIES=10
RETRY_DELAY=3
PHONE_MAC=""  # Will set this later

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Wait for bluetooth
log "Waiting for bluetooth service..."
for i in {1..15}; do
    if systemctl is-active --quiet bluetooth.service; then
        log "Bluetooth service active"
        break
    fi
    sleep 1
done
sleep 3

log "Starting connection service..."

# Unblock and power on
sudo rfkill unblock bluetooth
sudo hciconfig hci0 up
bluetoothctl power on
sleep 2

bluetoothctl discoverable on
bluetoothctl pairable on

if [ -n "$PHONE_MAC" ]; then
    log "Connecting to $PHONE_MAC"
    bluetoothctl trust "$PHONE_MAC" 2>&1 | tee -a "$LOG_FILE"
    
    for i in $(seq 1 $MAX_RETRIES); do
        log "Attempt $i/$MAX_RETRIES..."
        if bluetoothctl connect "$PHONE_MAC" 2>&1 | tee -a "$LOG_FILE" | grep -q "Connection successful"; then
            log "Connected successfully"
            break
        fi
        if [ $i -lt $MAX_RETRIES ]; then
            sleep $RETRY_DELAY
        fi
    done
fi

log "Monitoring connection..."
while true; do
    sleep 30
    if [ -n "$PHONE_MAC" ]; then
        if ! bluetoothctl info "$PHONE_MAC" 2>/dev/null | grep -q "Connected: yes"; then
            log "Reconnecting..."
            bluetoothctl connect "$PHONE_MAC"
        fi
    fi
done
EOF

sudo chmod +x /usr/local/bin/bt-connect.sh

# Create systemd service
sudo tee /etc/systemd/system/bt-connect.service > /dev/null << 'EOF'
[Unit]
Description=Bluetooth Auto-Connect
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/local/bin/bt-connect.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure ALSA for headphone jack
sudo tee /etc/asound.conf > /dev/null << 'EOF'
pcm.!default {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}
EOF

# Set audio to headphone jack
sudo raspi-config nonint do_audio 1
amixer sset Master 80% unmute

# Disable unused services
sudo systemctl disable hciuart.service 2>/dev/null || true
sudo systemctl disable triggerhappy.service 2>/dev/null || true
sudo systemctl disable avahi-daemon.service 2>/dev/null || true

# Enable bluetooth
sudo systemctl enable bluetooth.service
sudo systemctl enable bt-connect.service

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next: Find your phone's MAC and pair it"

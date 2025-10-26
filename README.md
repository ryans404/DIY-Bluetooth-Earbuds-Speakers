Complete Raspberry Pi 1 Bluetooth Audio Receiver Setup
Turn Wired Speakers/Headphones into Bluetooth (Battle-Tested)
This guide will walk you through turning any wired audio device into a Bluetooth receiver using a Raspberry Pi 1. Stream music wirelessly from your phone to wired earbuds, speakers, or any aux-connected device.

🔧 What You Need

* Raspberry Pi 1 (Model B or B+)
* USB Bluetooth dongle
* Aux cable (3.5mm to 3.5mm) or wired earbuds/headphones
* USB power cable (micro-USB, 2A power supply)
* SD card (8GB+, Class 10 recommended)
* Computer to prepare SD card
* Keyboard and monitor (temporary, just for setup)


📀 Part 1: Prepare SD Card
Step 1: Download Raspberry Pi OS

Go to: https://www.raspberrypi.com/software/operating-systems/
Download Raspberry Pi OS Lite (Legacy, 32-bit) - best for Pi 1
This is the non-desktop version

Step 2: Flash SD Card

Install Raspberry Pi Imager: https://www.raspberrypi.com/software/
Open Imager
Choose OS → Raspberry Pi OS (Legacy, 32-bit) Lite
Choose Storage → Your SD card
Click Write
Wait and eject when done


🖥️ Part 2: Initial Pi Setup
Step 3: First Boot

Insert SD card into Pi
Connect keyboard and monitor
Insert USB Bluetooth dongle
Connect wired earbuds/headphones/speakers to Pi's headphone jack
Power on via USB (2A recommended)

Step 4: Login

Username: pi
Password: raspberry

Step 5: Basic Configuration
bashsudo raspi-config
Configure:

1 System Options → S3 Password → Set new password
2. Customize anything else you need/want.

📝 Part 3: Install Bluetooth Software
Step 6: After Reboot, Create Setup Script
Login again, then:
bashnano setup-bt-minimal.sh
Paste this script:
bash#!/bin/bash
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
Save: Ctrl+X → Y → Enter
Step 7: Run Setup
bashchmod +x setup-bt-minimal.sh
sudo ./setup-bt-minimal.sh
Wait 5-10 minutes for installation.

📱 Part 4: Pair Your Phone
Step 8: Unblock Bluetooth (Critical!)
bashsudo rfkill unblock bluetooth
sudo hciconfig hci0 up
Step 9: Find Phone's MAC Address
bashbluetoothctl
```

In bluetoothctl:
```
power on
scan on
```

**Turn on Bluetooth on your phone.** Look for your phone name:
```
[NEW] Device AA:BB:CC:DD:EE:FF Your Phone Name
```

**Write down the MAC address.**
```
exit
Step 10: Add MAC to Script
bashsudo nano /usr/local/bin/bt-connect.sh
Find:
bashPHONE_MAC=""
Change to (use YOUR MAC):
bashPHONE_MAC="AA:BB:CC:DD:EE:FF"
Save: Ctrl+X → Y → Enter
Step 11: Pair Phone
bashbluetoothctl
```

Commands:
```
power on
scan on
```

Wait for your phone to appear, then:
```
pair AA:BB:CC:DD:EE:FF
```

**Accept pairing on your phone when prompted.**

Then:
```
trust AA:BB:CC:DD:EE:FF
connect AA:BB:CC:DD:EE:FF
exit
Step 12: Start Bluetooth Service
bashsudo systemctl restart bt-connect.service
Check it's running:
bashtail -f /var/log/bt-connect.log
Should say "Connected successfully". Press Ctrl+C to exit.

🔊 Part 5: Configure Audio
Step 13: Stop Default Audio Service
bashsudo systemctl stop bluealsa-aplay
sudo systemctl disable bluealsa-aplay
Step 14: Create Custom Audio Service
bashsudo nano /etc/systemd/system/bluealsa-aplay.service
```

Paste (use YOUR phone's MAC):
```
[Unit]
Description=BlueALSA Audio Player
After=bluealsa.service bt-connect.service
Requires=bluealsa.service

[Service]
Type=simple
ExecStart=/usr/bin/bluealsa-aplay --pcm=hw:0,0 AA:BB:CC:DD:EE:FF
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
Save: Ctrl+X → Y → Enter
Step 15: Enable Audio Service
bashsudo systemctl daemon-reload
sudo systemctl enable bluealsa-aplay.service
sudo systemctl start bluealsa-aplay.service
Step 16: Test Audio
Play music on your phone - you should hear it through your wired earbuds/speakers! 🔊

🎯 Part 6: Enable Auto-Login & Final Test
Step 17: Enable Auto-Login
bashsudo raspi-config

1 System Options
S5 Boot / Auto Login
Select B2 Console Autologin
Finish → Yes to reboot

Step 18: Final Reboot Test
After reboot (~60 seconds):

Should auto-login
Should auto-connect to phone
Play music → should work automatically


✅ You're Done!
Your Raspberry Pi is now a Bluetooth audio receiver. Any wired audio device connected to the Pi's headphone jack will receive audio wirelessly from your phone.

🔧 Troubleshooting
Bluetooth won't power on
bashsudo rfkill unblock bluetooth
sudo hciconfig hci0 up
Phone won't pair
Make sure Bluetooth is discoverable on phone. Try:
bashbluetoothctl
remove AA:BB:CC:DD:EE:FF
pair AA:BB:CC:DD:EE:FF
trust AA:BB:CC:DD:EE:FF
connect AA:BB:CC:DD:EE:FF
No audio
Check audio service:
bashsudo systemctl status bluealsa-aplay
Make sure ALSA config is correct:
bashcat /etc/asound.conf
Should use hw:0,0 for headphone jack.
Connection drops
Check logs:
bashtail -f /var/log/bt-connect.log
Service will auto-retry every 30 seconds.

📊 What You Get
✅ Auto-boots without keyboard/monitor
✅ Auto-connects to your phone
✅ Auto-routes audio through headphone jack
✅ Auto-reconnects if connection drops
✅ Works like a commercial Bluetooth receiver

🔄 Connecting a Different Phone
Temporary (one-time use):
bashbluetoothctl
scan on
pair NEW:MAC:ADDRESS
trust NEW:MAC:ADDRESS
connect NEW:MAC:ADDRESS
exit

sudo killall bluealsa-aplay
bluealsa-aplay --pcm=hw:0,0 NEW:MAC:ADDRESS &
Permanent (change default):

Edit /usr/local/bin/bt-connect.sh - change PHONE_MAC
Edit /etc/systemd/system/bluealsa-aplay.service - change MAC in ExecStart
sudo systemctl daemon-reload && sudo systemctl restart bt-connect.service bluealsa-aplay.service


💡 Tips

Use 2A USB power for stable operation
Pi 1 takes 45-60 seconds to boot
Control volume with phone or adjust with alsamixer
Can be powered by USB power bank for portable use
Works with any device that has Bluetooth audio output


🎧 Use Cases

Make old wired speakers Bluetooth-enabled
Turn wired earbuds into wireless (with portable battery)
Add Bluetooth to home stereo system
Create a wireless audio receiver for any aux-input device
Budget alternative to commercial Bluetooth receivers


Total setup time: ~30 minutes
Cost: ~$50 (Pi + accessories)
Result: Any wired audio becomes Bluetooth! 🎵🔊

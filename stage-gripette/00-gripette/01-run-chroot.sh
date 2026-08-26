#!/bin/bash

echo "Installing UV tool..."
rm -Rf /opt/uv
mkdir -p /opt/uv
chown -R pollen:pollen /opt/uv
runuser -u pollen -- curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/opt/uv" sh
echo 'export PATH=$PATH:/opt/uv' >> /home/pollen/.bashrc

echo "Building the gripette venv (make install-rpi equivalent)..."
chown -R pollen:pollen /home/pollen/grabette
cd /home/pollen/grabette
# --system-site-packages so apt's picamera2/numpy satisfy the dependency tree
# (PyPI picamera2 would otherwise pull a numpy build); numpy skipped for the
# same reason — mirrors packages/gripette/Makefile install-rpi.
runuser -u pollen -- env HOME=/home/pollen /opt/uv/uv venv \
    --python /usr/bin/python3 --system-site-packages
runuser -u pollen -- env HOME=/home/pollen /opt/uv/uv sync \
    --package gripette --extra rpi --no-install-package numpy

echo "Verifying imports (chroot-safe, touches no hardware)..."
runuser -u pollen -- /home/pollen/grabette/.venv/bin/python \
    -c "import picamera2, serial, rustypot, gripette; print('all imports OK')"

echo "Forcing BLE-only Bluetooth (ensure-ble-only equivalent)..."
BT_CONF=/etc/bluetooth/main.conf
grep -q '^\[General\]' "$BT_CONF" || printf '\n[General]\n' >> "$BT_CONF"
if grep -Eq '^[#[:space:]]*ControllerMode' "$BT_CONF"; then
    sed -i -E 's/^[#[:space:]]*ControllerMode.*/ControllerMode = le/' "$BT_CONF"
else
    sed -i '/^\[General\]/a ControllerMode = le' "$BT_CONF"
fi

echo "Enabling gripette services (web stays opt-in)..."
systemctl enable gripette gripette-bluetooth

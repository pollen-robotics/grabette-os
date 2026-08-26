#!/bin/bash

echo "Installing UV tool..."
rm -Rf /opt/uv
mkdir -p /opt/uv
chown -R pollen:pollen /opt/uv
runuser -u pollen -- curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/opt/uv" sh
echo 'export PATH=$PATH:/opt/uv' >> /home/pollen/.bashrc

echo "Building the grabette venv (make install-rpi equivalent)..."
chown -R pollen:pollen /home/pollen/grabette
cd /home/pollen/grabette
# --system-site-packages so apt's libcamera/picamera2 satisfy the dependency
# tree — mirrors packages/grabette/Makefile install-rpi.
runuser -u pollen -- env HOME=/home/pollen /opt/uv/uv venv \
    --python /usr/bin/python3 --system-site-packages
runuser -u pollen -- env HOME=/home/pollen /opt/uv/uv sync \
    --package grabette --extra rpi --extra ui --extra hf

echo "Verifying imports (chroot-safe, touches no hardware)..."
runuser -u pollen -- /home/pollen/grabette/.venv/bin/python \
    -c "import picamera2, depthai, cv2, gpiod, numpy, grabette; print('all imports OK')"

echo "Enabling grabette services..."
systemctl enable grabette grabette-bluetooth

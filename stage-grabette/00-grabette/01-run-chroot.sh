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
# The clone skips LFS, but the dashboard's 3D viewer serves the URDF meshes
# (/urdf/grabette_<hand>/assets/*.stl): fetch those, both hands (~70 MB).
runuser -u pollen -- env HOME=/home/pollen \
    git lfs pull --include="packages/grabette/urdf/**"
# --system-site-packages so apt's libcamera/picamera2 satisfy the dependency
# tree — mirrors packages/grabette/Makefile install-rpi.
runuser -u pollen -- env HOME=/home/pollen /opt/uv/uv venv \
    --python /usr/bin/python3 --system-site-packages
runuser -u pollen -- env HOME=/home/pollen /opt/uv/uv sync \
    --package grabette --extra rpi --extra ui --extra hf
# Gemini 305 (the default depth camera) SDK — install-orbbec-sdk equivalent.
# --no-deps on purpose: see that target in packages/grabette/Makefile.
runuser -u pollen -- env HOME=/home/pollen /opt/uv/uv pip install \
    --python /home/pollen/grabette/.venv/bin/python --no-deps pyorbbecsdk2

echo "Verifying imports (chroot-safe, touches no hardware)..."
runuser -u pollen -- /home/pollen/grabette/.venv/bin/python \
    -c "import picamera2, depthai, pyorbbecsdk, cv2, gpiod, numpy, grabette; print('all imports OK')"

# HAT speaker — install-audio equivalent, from the baked checkout (these files
# need no adaptation, so no copies to drift). config.txt enables the overlay.
# Inert on a grabette without a speaker. /etc/asound.conf is deliberately not
# written: the Makefile only does so once the card exists, and the daemon names
# the card itself.
echo "Installing HAT speaker overlay and mixer init..."
PKG=/home/pollen/grabette/packages/grabette
dtc -@ -I dts -O dtb -o /boot/firmware/overlays/tlv320aic3104.dtbo \
    "$PKG/config/overlays/tlv320aic3104-overlay.dts"
install -m 0755 "$PKG/scripts/aic3104-init.sh" /usr/local/bin/aic3104-init.sh
install -m 0644 "$PKG/systemd/aic3104-init.service" /etc/systemd/system/aic3104-init.service

echo "Enabling grabette services..."
systemctl enable grabette grabette-bluetooth aic3104-init

#!/bin/bash

# Grabette host-side setup. Shared work (grabette monorepo clone, crash
# hardening, hand-from-hostname script, BLE-only, VERSION.txt) lives in
# common/common-setup.sh.

OS_NAME=GrabetteOS
source "$(dirname "${BASH_SOURCE[0]}")/../../common/common-setup.sh"

echo "Installing grabette boot config (i2c3/i2c4 angle-sensor overlays)..."
install -m 0644 files/config.txt "${ROOTFS_DIR}/boot/firmware/config.txt"

echo "Installing grabette systemd units..."
install -m 0644 files/grabette.service files/grabette-bluetooth.service \
    "${ROOTFS_DIR}/etc/systemd/system/"

echo "Installing OAK-D udev rule..."
install -m 0644 files/80-movidius.rules "${ROOTFS_DIR}/etc/udev/rules.d/80-movidius.rules"

echo "Installing NTP config for multi-device recording sync (install-ntp equivalent)..."
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/timesyncd.conf.d"
install -m 0644 files/timesyncd-grabette.conf \
    "${ROOTFS_DIR}/etc/systemd/timesyncd.conf.d/grabette.conf"

echo "Installing polkit rules for WiFi scan/connect from the dashboard (install-netdev equivalent)..."
# The 'usermod -aG netdev' half is already covered: stock stage2 adds the
# first user to netdev.
install -d -m 0755 "${ROOTFS_DIR}/etc/polkit-1/rules.d"
install -m 0644 files/10-grabette-wifi-scan.rules files/10-grabette-wifi-connect.rules \
    "${ROOTFS_DIR}/etc/polkit-1/rules.d/"

echo "Installing /etc/grabette/env defaults..."
install -d -m 0755 "${ROOTFS_DIR}/etc/grabette"
install -m 0644 files/grabette-env "${ROOTFS_DIR}/etc/grabette/env"

echo "Installing poweroff sudoers (install-poweroff equivalent)..."
install -m 0440 files/sudoers-grabette-poweroff "${ROOTFS_DIR}/etc/sudoers.d/grabette-poweroff"
# Fail the build if the sudoers file is malformed (a bad file locks out sudo).
on_chroot <<- EOF
	visudo -cf /etc/sudoers.d/grabette-poweroff
EOF

echo "Installing check script..."
install -m 0755 files/grabetteos_check.sh "${ROOTFS_DIR}/usr/local/bin/grabetteos_check"

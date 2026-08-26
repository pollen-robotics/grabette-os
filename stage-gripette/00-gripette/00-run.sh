#!/bin/bash

# Gripette host-side setup. Shared work (grabette monorepo clone, crash
# hardening, hand-from-hostname script, BLE-only, VERSION.txt) lives in
# common/common-setup.sh.

OS_NAME=GripetteOS
source "$(dirname "${BASH_SOURCE[0]}")/../../common/common-setup.sh"

echo "Installing gripette boot config (PL011 UART on the header)..."
install -m 0644 files/config.txt "${ROOTFS_DIR}/boot/firmware/config.txt"

echo "Installing gripette systemd units..."
install -m 0644 files/gripette.service files/gripette-bluetooth.service \
    files/gripette-web.service "${ROOTFS_DIR}/etc/systemd/system/"

echo "Installing /etc/gripette/env defaults..."
install -d -m 0755 "${ROOTFS_DIR}/etc/gripette"
install -m 0644 files/gripette-env "${ROOTFS_DIR}/etc/gripette/env"

echo "Installing scoped sudoers for the web UI..."
install -m 0440 files/sudoers-gripette-web "${ROOTFS_DIR}/etc/sudoers.d/gripette-web"
# Fail the build if the sudoers file is malformed (a bad file locks out sudo).
on_chroot <<- EOF
	visudo -cf /etc/sudoers.d/gripette-web
EOF

echo "Installing check script..."
install -m 0755 files/gripetteos_check.sh "${ROOTFS_DIR}/usr/local/bin/gripetteos_check"

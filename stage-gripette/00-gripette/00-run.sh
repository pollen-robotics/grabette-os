#!/bin/bash

# Gripette host-side setup. Shared work (grabette monorepo clone, crash
# hardening, hand-from-hostname script) lives in common/common-setup.sh.

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
install -d -m 0755 "${ROOTFS_DIR}/etc/sudoers.d"
install -m 0440 files/sudoers-gripette-web "${ROOTFS_DIR}/etc/sudoers.d/gripette-web"
# Fail the build if the sudoers file is malformed (a bad file locks out sudo).
on_chroot <<- EOF
	visudo -cf /etc/sudoers.d/gripette-web
EOF

echo "Creating VERSION.txt..."
rm -f "${ROOTFS_DIR}/home/pollen/VERSION.txt"
echo "GripetteOS: dev" > "${ROOTFS_DIR}/home/pollen/VERSION.txt"
echo "Grabette ref: ${GRABETTE_REF}" >> "${ROOTFS_DIR}/home/pollen/VERSION.txt"
echo "Created on: $(date '+%Y-%m-%d')" >> "${ROOTFS_DIR}/home/pollen/VERSION.txt"

echo "Installing check script..."
install -m 0755 files/gripetteos_check.sh "${ROOTFS_DIR}/usr/local/bin/gripetteos_check"

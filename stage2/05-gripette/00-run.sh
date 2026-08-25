#!/bin/bash

# Host-side gripette setup: clone the app repo into the rootfs and install
# config files. GITHUB_TOKEN (contents:read on pollen-robotics/grabette) and
# GRIPETTE_REF (branch/tag to build, default develop) come from the build
# environment: sudo -E GITHUB_TOKEN=... GRIPETTE_REF=... ./build.sh

GRIPETTE_REF="${GRIPETTE_REF:-develop}"

if [ -z "${GITHUB_TOKEN}" ]; then
    echo "ERROR: GITHUB_TOKEN is not set — needed to clone the private" \
         "pollen-robotics/grabette repo. Run: sudo -E GITHUB_TOKEN=... ./build.sh" >&2
    exit 1
fi

echo "Cloning grabette (${GRIPETTE_REF}) into the image..."
rm -rf "${ROOTFS_DIR}/home/pollen/grabette"
GIT_LFS_SKIP_SMUDGE=1 git clone --branch "${GRIPETTE_REF}" --depth 1 \
    "https://x-access-token:${GITHUB_TOKEN}@github.com/pollen-robotics/grabette.git" \
    "${ROOTFS_DIR}/home/pollen/grabette"
# Scrub the token from the baked .git/config.
git -C "${ROOTFS_DIR}/home/pollen/grabette" remote set-url origin \
    "https://github.com/pollen-robotics/grabette.git"

echo "Installing persistent journald config (harden-rpi equivalent)..."
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/journald.conf.d"
install -m 0644 files/10-gripette-journald.conf \
    "${ROOTFS_DIR}/etc/systemd/journald.conf.d/10-gripette-journald.conf"
install -d "${ROOTFS_DIR}/var/log/journal"

echo "Installing gripette systemd units..."
install -m 0644 files/gripette.service files/gripette-bluetooth.service \
    files/gripette-web.service "${ROOTFS_DIR}/etc/systemd/system/"

echo "Installing hand-from-hostname script..."
install -m 0755 files/gripette-hand-from-hostname \
    "${ROOTFS_DIR}/usr/local/bin/gripette-hand-from-hostname"

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
echo "Grabette ref: ${GRIPETTE_REF}" >> "${ROOTFS_DIR}/home/pollen/VERSION.txt"
echo "Created on: $(date '+%Y-%m-%d')" >> "${ROOTFS_DIR}/home/pollen/VERSION.txt"

echo "Installing check script..."
install -m 0755 files/gripetteos_check.sh "${ROOTFS_DIR}/usr/local/bin/gripetteos_check"

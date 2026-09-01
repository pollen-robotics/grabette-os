# Shared host-side setup for both device stages (gripette, grabette).
# Sourced by each stage's 00-run.sh — NOT executable on its own.
# Does everything identical across variants: monorepo clone, crash hardening
# (persistent journal + fsck.mode=force cmdline), hand-from-hostname script,
# BLE-only bluetooth, VERSION.txt.
#
# Needs from the environment: ROOTFS_DIR (pi-gen), GRABETTE_REF (branch/tag,
# default develop), OS_VERSION (image version stamp, default dev).
# Needs from the sourcing script: OS_NAME (e.g. GripetteOS).

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRABETTE_REF="${GRABETTE_REF:-develop}"

echo "Cloning grabette (${GRABETTE_REF}) into the image..."
rm -rf "${ROOTFS_DIR}/home/pollen/grabette"
GIT_LFS_SKIP_SMUDGE=1 git clone --branch "${GRABETTE_REF}" --depth 1 \
    "https://github.com/pollen-robotics/grabette.git" \
    "${ROOTFS_DIR}/home/pollen/grabette"

echo "Installing persistent journald config..."
install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/journald.conf.d"
install -m 0644 "${COMMON_DIR}/files/10-journald-persistent.conf" \
    "${ROOTFS_DIR}/etc/systemd/journald.conf.d/10-journald-persistent.conf"
install -d "${ROOTFS_DIR}/var/log/journal"

echo "Installing hardened cmdline.txt (no serial console, fsck.mode=force)..."
# ROOTDEV is substituted by export-image/04-set-partuuid at export time,
# which runs after all stages — overwriting stage1's copy here is safe.
install -m 0644 "${COMMON_DIR}/files/cmdline.txt" \
    "${ROOTFS_DIR}/boot/firmware/cmdline.txt"

echo "Installing hand-from-hostname script..."
install -m 0755 "${COMMON_DIR}/files/hand-from-hostname" \
    "${ROOTFS_DIR}/usr/local/bin/hand-from-hostname"

echo "Installing hostname-suffix (per-device hostname uniqueness)..."
install -m 0755 "${COMMON_DIR}/files/hostname-suffix" \
    "${ROOTFS_DIR}/usr/local/bin/hostname-suffix"
install -m 0644 "${COMMON_DIR}/files/hostname-suffix.service" \
    "${ROOTFS_DIR}/etc/systemd/system/hostname-suffix.service"
on_chroot <<- EOF
	systemctl enable hostname-suffix
EOF

echo "Forcing BLE-only Bluetooth (ensure-ble-only equivalent)..."
BT_CONF="${ROOTFS_DIR}/etc/bluetooth/main.conf"
grep -q '^\[General\]' "$BT_CONF" || printf '\n[General]\n' >> "$BT_CONF"
if grep -Eq '^[#[:space:]]*ControllerMode' "$BT_CONF"; then
    sed -i -E 's/^[#[:space:]]*ControllerMode.*/ControllerMode = le/' "$BT_CONF"
else
    sed -i '/^\[General\]/a ControllerMode = le' "$BT_CONF"
fi

echo "Creating VERSION.txt..."
{
    echo "${OS_NAME}: ${OS_VERSION:-dev}"
    echo "Grabette ref: ${GRABETTE_REF}"
    echo "Created on: $(date '+%Y-%m-%d')"
} > "${ROOTFS_DIR}/home/pollen/VERSION.txt"

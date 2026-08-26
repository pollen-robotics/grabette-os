# Shared host-side setup for both device stages (gripette, grabette).
# Sourced by each stage's 00-run.sh — NOT executable on its own.
# Does everything identical across variants: monorepo clone, crash hardening
# (persistent journal + fsck.mode=force cmdline), hand-from-hostname script.
#
# Needs from the environment: ROOTFS_DIR (pi-gen), GITHUB_TOKEN (contents:read
# on pollen-robotics/grabette), GRABETTE_REF (branch/tag, default develop).

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRABETTE_REF="${GRABETTE_REF:-develop}"

if [ -z "${GITHUB_TOKEN}" ]; then
    echo "ERROR: GITHUB_TOKEN is not set — needed to clone the private" \
         "pollen-robotics/grabette repo." \
         "Run: sudo -E GITHUB_TOKEN=... ./build.sh -c config.<variant>" >&2
    exit 1
fi

echo "Cloning grabette (${GRABETTE_REF}) into the image..."
rm -rf "${ROOTFS_DIR}/home/pollen/grabette"
GIT_LFS_SKIP_SMUDGE=1 git clone --branch "${GRABETTE_REF}" --depth 1 \
    "https://x-access-token:${GITHUB_TOKEN}@github.com/pollen-robotics/grabette.git" \
    "${ROOTFS_DIR}/home/pollen/grabette"
# Scrub the token from the baked .git/config.
git -C "${ROOTFS_DIR}/home/pollen/grabette" remote set-url origin \
    "https://github.com/pollen-robotics/grabette.git"

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

#!/bin/bash
# Verify a built GrabetteOS/GripetteOS image without flashing it.
# Runs inside a privileged container: bash /v/verify-image.sh <zip-in-deploy> <variant>
set -u
ZIP="$1"; VARIANT="$2"   # gripette | grabette
FAIL=0
ck() { # ck "label" <command...>
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "PASS: $label"; else echo "FAIL: $label"; FAIL=1; fi
}
ckno() { # inverted: passes when the command finds nothing
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "FAIL: $label"; FAIL=1; else echo "PASS: $label"; fi
}

rm -rf /v/verify && mkdir -p /v/verify
bsdtar -xf "/v/deploy/${ZIP}" -C /v/verify || { echo "ABORT: cannot extract ${ZIP}"; exit 1; }
IMG=$(ls /v/verify/*.img) || { echo "ABORT: no .img extracted"; exit 1; }
LOOP=$(losetup -P -f --show "$IMG") || { echo "ABORT: losetup failed"; exit 1; }
# Docker mounts tmpfs on /dev, so kernel-created partition nodes don't appear;
# create them from sysfs.
for p in /sys/class/block/$(basename "$LOOP")p*; do
    [ -e "/dev/$(basename "$p")" ] && continue
    nr=$(cat "$p/dev")
    mknod "/dev/$(basename "$p")" b "${nr%%:*}" "${nr##*:}"
done
mkdir -p /mnt/vboot /mnt/vroot
mount -o ro "${LOOP}p1" /mnt/vboot || { echo "ABORT: boot mount failed"; exit 1; }
mount -o ro "${LOOP}p2" /mnt/vroot || { echo "ABORT: root mount failed"; exit 1; }
B=/mnt/vboot R=/mnt/vroot

echo "=== common checks ($VARIANT) ==="
ck "cmdline: fsck.mode=force"            grep -q 'fsck.mode=force' $B/cmdline.txt
ckno "cmdline: no serial console"        grep -Eq 'console=(serial0|ttyAMA0|ttyS0)' $B/cmdline.txt
ck "cmdline: real PARTUUID substituted"  grep -q 'root=PARTUUID=' $B/cmdline.txt
ck "journald persistent drop-in"         grep -q 'Storage=persistent' $R/etc/systemd/journald.conf.d/10-journald-persistent.conf
ck "/var/log/journal exists"             test -d $R/var/log/journal
ck "hand-from-hostname installed +x"     test -x $R/usr/local/bin/hand-from-hostname
ck "monorepo checkout present"           test -f $R/home/pollen/grabette/pyproject.toml
ck "venv python present"                 test -L $R/home/pollen/grabette/.venv/bin/python
ck "venv uses system site-packages"      grep -q 'include-system-site-packages = true' $R/home/pollen/grabette/.venv/pyvenv.cfg
ckno "no token left in .git/config"      grep -q 'x-access-token' $R/home/pollen/grabette/.git/config
ck "bluetooth BLE-only"                  grep -q '^ControllerMode = le' $R/etc/bluetooth/main.conf
ck "kernel pinned 6.18.33"               ls -d $R/lib/modules/6.18.33*
ck "VERSION.txt"                         grep -q 'OS:' $R/home/pollen/VERSION.txt
ck "pollen user exists"                  grep -q '^pollen:' $R/etc/passwd
ck "pollen in dialout+netdev+video"      bash -c "grep -E '^(dialout|netdev|video):' $R/etc/group | grep -vc pollen | grep -qx 0"
ck "ssh enabled"                         test -L $R/etc/systemd/system/multi-user.target.wants/ssh.service -o -L $R/etc/systemd/system/sshd.service

echo "=== $VARIANT checks ==="
if [ "$VARIANT" = gripette ]; then
    ck "config.txt: miniuart-bt"         grep -q '^\s*dtoverlay=miniuart-bt' $B/config.txt
    ck "config.txt: enable_uart=1"       grep -q '^enable_uart=1' $B/config.txt
    ck "env defaults, no HAND yet"       bash -c "grep -q GRIPPER_CAMERA_MODE=video $R/etc/gripette/env && ! grep -q ^GRIPPER_HAND= $R/etc/gripette/env"
    ck "gripette.service baked"          grep -q 'User=pollen' $R/etc/systemd/system/gripette.service
    ck "gripette.service hand ExecStartPre" grep -q 'ExecStartPre=+/usr/local/bin/hand-from-hostname /etc/gripette/env GRIPPER_HAND' $R/etc/systemd/system/gripette.service
    ck "gripette enabled"                test -L $R/etc/systemd/system/multi-user.target.wants/gripette.service
    ck "gripette-bluetooth enabled"      test -L $R/etc/systemd/system/multi-user.target.wants/gripette-bluetooth.service
    ckno "gripette-web NOT enabled"      test -L $R/etc/systemd/system/multi-user.target.wants/gripette-web.service
    ck "web sudoers 0440"                bash -c "stat -c%a $R/etc/sudoers.d/gripette-web | grep -qx 440"
    ck "check script"                    test -x $R/usr/local/bin/gripetteos_check
    ck "gripette pkg in venv"            ls -d $R/home/pollen/grabette/.venv/lib/python*/site-packages/gripette*
else
    ck "config.txt: i2c3 overlay"        grep -q 'dtoverlay=i2c3,pins_4_5' $B/config.txt
    ck "config.txt: i2c4 overlay"        grep -q 'dtoverlay=i2c4,pins_8_9' $B/config.txt
    ck "config.txt: i2c_arm on"          grep -q '^dtparam=i2c_arm=on' $B/config.txt
    ck "env defaults, no HAND yet"       bash -c "test -f $R/etc/grabette/env && ! grep -q ^GRABETTE_HAND= $R/etc/grabette/env"
    ck "grabette.service baked"          grep -q 'User=pollen' $R/etc/systemd/system/grabette.service
    ck "grabette.service hand ExecStartPre" grep -q 'ExecStartPre=+/usr/local/bin/hand-from-hostname /etc/grabette/env GRABETTE_HAND' $R/etc/systemd/system/grabette.service
    ck "grabette enabled"                test -L $R/etc/systemd/system/multi-user.target.wants/grabette.service
    ck "grabette-bluetooth enabled"      test -L $R/etc/systemd/system/multi-user.target.wants/grabette-bluetooth.service
    ck "OAK-D udev rule"                 grep -q 'idVendor}=="03e7"' $R/etc/udev/rules.d/80-movidius.rules
    ck "NTP pinned to cloudflare"        grep -q 'NTP=time.cloudflare.com' $R/etc/systemd/timesyncd.conf.d/grabette.conf
    ck "polkit wifi scan rule"           grep -q 'wifi.scan' $R/etc/polkit-1/rules.d/10-grabette-wifi-scan.rules
    ck "polkit wifi connect rule"        grep -q 'network-control' $R/etc/polkit-1/rules.d/10-grabette-wifi-connect.rules
    ck "poweroff sudoers 0440"           bash -c "stat -c%a $R/etc/sudoers.d/grabette-poweroff | grep -qx 440"
    ck "check script"                    test -x $R/usr/local/bin/grabetteos_check
    ck "grabette pkg in venv"            ls -d $R/home/pollen/grabette/.venv/lib/python*/site-packages/grabette*
    ck "depthai in venv"                 ls -d $R/home/pollen/grabette/.venv/lib/python*/site-packages/depthai*
fi

# Writable /tmp for the chroot checks (systemd-analyze needs a working dir);
# the image itself stays read-only.
mount -t tmpfs tmpfs "$R/tmp" || echo "warn: no tmpfs on /tmp"

echo "=== runtime checks (qemu chroot, read-only) ==="
PY=/home/pollen/grabette/.venv/bin/python
if [ "$VARIANT" = gripette ]; then MODS="gripette, gripette.bluetooth, gripette.webui, dbus, gi"; else MODS="grabette, grabette.bluetooth, dbus, gi"; fi
ck "service entry modules import" \
    chroot $R env PYTHONDONTWRITEBYTECODE=1 $PY -c "import ${MODS}"
ck "on-device scripts parse on image python" \
    chroot $R env PYTHONDONTWRITEBYTECODE=1 $PY -c "import ast,glob; [ast.parse(open(f).read(),f) for f in glob.glob('/home/pollen/grabette/packages/${VARIANT}/scripts/*.py')]"
ck "systemd-analyze verify units" \
    chroot $R systemd-analyze verify /etc/systemd/system/${VARIANT}.service /etc/systemd/system/${VARIANT}-bluetooth.service

echo "=== hand-from-hostname behavior (via qemu chroot) ==="
# binfmt_misc with the F flag lets us chroot into the aarch64 rootfs.
# The rootfs is mounted ro — put tmpfs over /tmp and /etc/<variant> so the
# script can write without touching the image.
if [ "$VARIANT" = gripette ]; then EF=/etc/gripette/env; VAR=GRIPPER_HAND; else EF=/etc/grabette/env; VAR=GRABETTE_HAND; fi
if mount -t tmpfs tmpfs "$R/etc/${VARIANT}"; then
    printf '#!/bin/sh\necho %s-left\n' "$VARIANT" > "$R/tmp/hostname"
    chmod +x "$R/tmp/hostname"
    if chroot $R /bin/sh -c "PATH=/tmp:\$PATH /usr/local/bin/hand-from-hostname $EF $VAR" \
        && grep -q "^${VAR}=left$" "$R$EF"; then
        echo "PASS: hand-from-hostname wrote ${VAR}=left in aarch64 chroot"
    else
        echo "FAIL: hand-from-hostname chroot test"; FAIL=1
    fi
    umount "$R/etc/${VARIANT}"
else
    echo "SKIP: tmpfs overlay for hand test"
fi

umount "$R/tmp" 2>/dev/null
umount /mnt/vboot /mnt/vroot
losetup -d "$LOOP"
rm -rf /v/verify
[ "$FAIL" = 0 ] && echo "=== ALL CHECKS PASSED ===" || echo "=== FAILURES PRESENT ==="
exit $FAIL

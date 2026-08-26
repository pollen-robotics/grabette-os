#!/bin/sh
# Quick GrabetteOS sanity check. For the full hardware diagnostic (camera,
# I2C angle sensors, OAK-D, button) run:
#   ~/grabette/.venv/bin/python ~/grabette/packages/grabette/scripts/check_hardware.py
rc=0
for svc in grabette grabette-bluetooth; do
    state=$(systemctl is-active "$svc" || true)
    echo "$svc: $state"
    [ "$state" = active ] || rc=1
done
echo "--- /etc/grabette/env ---"
cat /etc/grabette/env 2>/dev/null || { echo "missing"; rc=1; }
echo "--- I2C buses (angle sensors) ---"
ls -l /dev/i2c-3 /dev/i2c-4 2>/dev/null || { echo "i2c-3/i2c-4 missing (config.txt overlays?)"; rc=1; }
exit $rc

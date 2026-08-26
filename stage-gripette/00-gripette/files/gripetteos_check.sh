#!/bin/sh
# Quick GripetteOS sanity check. For the full hardware diagnostic
# (camera capture + motor bus) run:  make -C ~/grabette/packages/gripette check
rc=0
for svc in gripette gripette-bluetooth; do
    state=$(systemctl is-active "$svc" || true)
    echo "$svc: $state"
    [ "$state" = active ] || rc=1
done
echo "--- /etc/gripette/env ---"
cat /etc/gripette/env 2>/dev/null || { echo "missing"; rc=1; }
echo "--- serial0 ---"
ls -l /dev/serial0 2>/dev/null || { echo "/dev/serial0 missing (PL011 not on header?)"; rc=1; }
exit $rc

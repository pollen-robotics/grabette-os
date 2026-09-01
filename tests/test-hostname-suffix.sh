#!/bin/sh
# Behavioural tests for common/files/hostname-suffix, runnable on any host in a
# second — no image build, no ARM. verify-image.sh additionally checks that the
# script and its unit land in the image.
#
# The script under test touches /etc and reads the Pi serial; both are relocated
# under a temp ROOT, and `hostname` is a fake on PATH that keeps the "running"
# name in a file, so this machine's hostname is never touched.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/common/files/hostname-suffix"
FAIL=0
SERIAL_HI=100000003d1f9a2b   # a real-shaped Pi serial; only the low digits vary

setup() { # setup <running-hostname> [serial]
    ROOT="$(mktemp -d)"
    BIN="$ROOT/bin"
    RUNNING="$ROOT/running-hostname"
    mkdir -p "$ROOT/etc" "$ROOT/sys/firmware/devicetree/base" "$BIN"
    printf '%s\n' "$1" > "$RUNNING"
    printf '%s\n' "$1" > "$ROOT/etc/hostname"
    printf '127.0.0.1\tlocalhost\n127.0.1.1\t%s\n' "$1" > "$ROOT/etc/hosts"
    # The devicetree node is NUL-terminated, like the real one.
    [ "${2-}" = "none" ] || printf '%s\0' "${2:-$SERIAL_HI}" \
        > "$ROOT/sys/firmware/devicetree/base/serial-number"
    cat > "$BIN/hostname" <<FAKE
#!/bin/sh
if [ \$# -eq 0 ]; then cat "$RUNNING"; else printf '%s\n' "\$1" > "$RUNNING"; fi
FAKE
    chmod +x "$BIN/hostname"
}

run() { ROOT="$ROOT" PATH="$BIN:$PATH" sh "$SCRIPT" >/dev/null 2>&1; }

ck() { # ck <label> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS: $1"
    else echo "FAIL: $1 — expected [$2], got [$3]"; FAIL=1; fi
}

echo "=== a pristine hostname gains the serial suffix ==="
setup grabette
run
ck "running hostname"  "grabette-1f9a2b" "$(cat "$RUNNING")"
ck "/etc/hostname"     "grabette-1f9a2b" "$(cat "$ROOT/etc/hostname")"
ck "/etc/hosts 127.0.1.1" "grabette-1f9a2b" \
   "$(awk '/^127\.0\.1\.1/{print $2}' "$ROOT/etc/hosts")"
ck "localhost line kept" "localhost" "$(awk '/^127\.0\.0\.1/{print $2}' "$ROOT/etc/hosts")"

echo "=== every variant, not just grabette ==="
for v in gripette casquette; do
    setup "$v"; run
    ck "$v" "$v-1f9a2b" "$(cat "$RUNNING")"
done

echo "=== a name someone already chose is left alone ==="
for h in grabette-left-1f9a2b grabette-left grabette-left-simsim; do
    setup "$h"; run
    ck "$h untouched" "$h" "$(cat "$RUNNING")"
done

echo "=== no readable serial: no-op, and a zero exit ==="
setup grabette none
ROOT="$ROOT" PATH="$BIN:$PATH" sh "$SCRIPT" >/dev/null 2>&1
ck "exit status" "0" "$?"
ck "hostname untouched" "grabette" "$(cat "$RUNNING")"

echo "=== idempotent across boots ==="
setup grabette
run; run; run
ck "suffix appended once" "grabette-1f9a2b" "$(cat "$RUNNING")"

echo "=== /etc/hosts with no 127.0.1.1 line gains one ==="
setup grabette
printf '127.0.0.1\tlocalhost\n' > "$ROOT/etc/hosts"
run
ck "127.0.1.1 appended" "grabette-1f9a2b" \
   "$(awk '/^127\.0\.1\.1/{print $2}' "$ROOT/etc/hosts")"

echo "=== the hand is still derivable from the suffixed name ==="
# hand-from-hostname globs *left* / *right*; hex can never spell either.
setup grabette
run
case "$(cat "$RUNNING")-left" in
    *left*) echo "PASS: globs *left* once the hand is appended" ;;
    *) echo "FAIL: hand no longer derivable"; FAIL=1 ;;
esac

[ "$FAIL" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$FAIL"

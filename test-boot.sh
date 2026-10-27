#!/usr/bin/env bash
set -euo pipefail
ISO="${1:?Usage: bash test-boot.sh dist/SkidUX_LinuxMint_LIVE_amd64.iso}"
test -s "$ISO"
sudo apt-get update -qq
sudo apt-get install -y -qq qemu-system-x86 socat python3-pil
mkdir -p dist/boot-test
MONITOR="$PWD/dist/boot-test/monitor.sock"
rm -f "$MONITOR"
ACCEL="tcg"
if [[ -r /dev/kvm && -w /dev/kvm ]]; then ACCEL="kvm"; fi
qemu-system-x86_64 -machine "accel=$ACCEL" -m 4096 -smp 2 -vga std \
  -cdrom "$ISO" -boot d -display none -serial file:"$PWD/dist/boot-test/serial.log" \
  -monitor "unix:$MONITOR,server,nowait" -net none >dist/boot-test/qemu.log 2>&1 &
PID=$!
trap 'kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true' EXIT
for i in $(seq 1 30); do [[ -S "$MONITOR" ]] && break; sleep 1; done
test -S "$MONITOR"
# A captured VM frame is diagnostic evidence, not a promise that Cinnamon loaded.
sleep 110
printf 'screendump %s\n' "$PWD/dist/boot-test/screen.ppm" | socat - UNIX-CONNECT:"$MONITOR" || true
test -s dist/boot-test/screen.ppm
python3 - <<'PY'
from PIL import Image
im = Image.open('dist/boot-test/screen.ppm').convert('RGB')
im.thumbnail((320, 180))
pixels=list(im.getdata())
bright=sum(max(p)>70 for p in pixels)
palette=len(set(pixels))
print(f'VM boot screenshot: size={im.size}, distinct_colors={palette}, visible_pixels={bright}/{len(pixels)}')
if palette < 12 or bright < len(pixels)//100:
    raise SystemExit('Boot test screen appears blank; investigate screenshot before releasing.')
PY
echo 'VM produced a nonblank screen. Manually review boot-test/screen.ppm for Cinnamon desktop vs firmware/terminal.'

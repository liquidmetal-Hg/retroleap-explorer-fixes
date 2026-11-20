#!/bin/bash
# Offline test of the fixed init scripts with the image's own busybox. User-namespace chroot on an aarch64 Linux host (tested: Raspberry Pi 5).
# Uses the patched ohboy as a real "emulator" (SDL dummy) to prove S55start_menu stop lets it save.
set -u
F=$(cd "$(dirname "$0")/.." && pwd)   # repo root (overlay/ is there)
RF=${1:?unpacked alpha10 rootfs}; BIN=${2:?patched ohboy binary}
ROM=${ROM:?set ROM=/path/to/a/battery-backed game.gb}
T=./work/scripts-testroot
rm -rf "$T"; cp -a "$RF" "$T"; cp -a "$F/overlay/." "$T/"; cp "$BIN" "$T/usr/bin/ohboy"
mkdir -p "$T/roms" "$T/dev" "$T/proc" "$T/stub" "$T/sys/devices/platform/lf1000-power"; cp "$ROM" "$T/roms/"
printf '#!/bin/sh\necho poweroff-called > /tmp/poweroff.marker\n' > "$T/stub/poweroff"
printf '#!/bin/sh\necho "$@" >> /tmp/logger.txt\n' > "$T/stub/logger"; chmod 755 "$T/stub/"*
echo 0 > "$T/sys/devices/platform/lf1000-power/shutdown"
inroot() { unshare -r -m -p -f --mount-proc /bin/sh -c "mount --rbind /dev '$T/dev' && mount -t proc proc '$T/proc' && exec chroot '$T' /bin/sh -c 'export PATH=/stub:/bin:/sbin:/usr/bin:/usr/sbin HOME=/configs SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy; $1'"; }
pass=0; fail=0; check() { if eval "$2"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }

echo "== shutdown_monitor.sh v2 (LF1000): input events via a FIFO; screen on -> poweroff, screen dark -> wake only"
mkdir -p "$T/sys/class/backlight/lf1000-pwm-bl"
printf '\001\000\000\000\000\000\000\000\001\000\164\000\001\000\000\000' > "$T/press.bin"    # EV_KEY KEY_POWER value 1
printf '\001\000\000\000\000\000\000\000\001\000\164\000\000\000\000\000' > "$T/release.bin"  # value 0
PRESS_CMD='cat /press.bin > /tmp/ev'; RELEASE_CMD='cat /release.bin > /tmp/ev'
mon() {  # $1 = brightness during the press, $2 = extra commands after the press
  echo "$1" > "$T/sys/class/backlight/lf1000-pwm-bl/brightness"; rm -f "$T/tmp/poweroff.marker" "$T/tmp/logger.txt" "$T/tmp/ev"
  inroot "mkfifo /tmp/ev; POWER_DEV=/tmp/ev /usr/bin/shutdown_monitor.sh & p=\$!; sleep 1; $RELEASE_CMD; $PRESS_CMD; sleep 1; $2 kill \$p 2>/dev/null; true"
}
mon 400 ""
check "screen on: power press -> poweroff" "[ -f $T/tmp/poweroff.marker ]"
mon 0 ""
check "screen dark: power press -> NO poweroff" "[ ! -f $T/tmp/poweroff.marker ]"
check "screen dark: logged as wake-up" "grep -q 'wake-up only' $T/tmp/logger.txt"
mon 0 "echo 400 > /sys/class/backlight/lf1000-pwm-bl/brightness; sleep 3; $PRESS_CMD; sleep 1;"
check "after wake-up, the next press (screen on) -> poweroff" "[ -f $T/tmp/poweroff.marker ]"
printf 'I: Bus=0019 Vendor=0001 Product=0001 Version=0100\nN: Name="LF1000 USB"\nH: Handlers=event0 \n\nN: Name="Power Button"\nP: Phys=\nH: Handlers=kbd event1 \n\nN: Name="LF1000 Keyboard"\nH: Handlers=kbd event2 \n' > "$T/tmp/devices.txt"
D=$(awk '/^N: Name="Power Button"/ {f=1} f && /^H: Handlers=/ {for (i=1;i<=NF;i++) if ($i ~ /event/) {sub("Handlers=","",$i); print $i; exit}}' "$T/tmp/devices.txt")
check "Power Button device found as event1 (real Leapster format)" "[ \"$D\" = event1 ]"

echo "== S50mount_data_mtd start when /roms is already a mount point: creates saves + flag file"
inroot 'mount -t tmpfs none /roms 2>/dev/null || mount --bind /roms /roms; /etc/init.d/S50mount_data_mtd start; ls -d /roms/saves && ls /tmp/roms_mounted' > "$T/tmp/s50.out" 2>&1
check "/roms/saves and /tmp/roms_mounted created" "grep -q /roms/saves $T/tmp/s50.out && grep -q roms_mounted $T/tmp/s50.out"

echo "== S55start_menu stop while ohboy runs: TERM, wait, ohboy saves, no forced kill"
rm -rf "$T/roms/saves"; rm -f "$T/tmp/logger.txt"
inroot 'mkdir -p /roms/saves; cd /usr/bin; /usr/bin/ohboy /roms/2048.gb >/tmp/ohboy.log 2>&1 & sleep 3; /etc/init.d/S55start_menu stop; echo stop-exit=$?; pidof ohboy && echo STILL-RUNNING || echo ohboy-gone' > "$T/tmp/s55.out" 2>&1
cat "$T/tmp/s55.out"
check "ohboy stopped by S55 stop" "grep -q ohboy-gone $T/tmp/s55.out"
check "ohboy wrote .sav and .aut during S55 stop" "[ -s $T/roms/saves/2048.sav ] && ls $T/roms/saves/2048.??????.aut >/dev/null 2>&1"
check "no forced kill logged" "! grep -q 'forced kill' $T/tmp/logger.txt 2>/dev/null"
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

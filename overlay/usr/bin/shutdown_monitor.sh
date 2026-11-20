#!/bin/sh
# Retroleap alpha10 + explorer-fixes (2026-11-19).
# LeapsterGS (LF2000): unchanged from alpha10: the kernel's shutdown flag -> poweroff.
# Leapster Explorer (LF1000), v2: listen to the "Power Button" input device itself.
#  - The kernel's /sys/devices/platform/lf1000-power/shutdown flag is set on every press and never
#    cleared, so it can't tell a second press from the first. Not used any more (only as fallback).
#  - gmenunx turns the screen off after its suspend timeout (backlight brightness 0) and wakes it on
#    Power. A press while the screen is (or just was) dark = wake-up only, no shutdown.
#  - A press with the screen on = clean shutdown (S55start_menu stop lets the emulator save first).
#  - Holding power >= 2 s still makes the kernel cut the power (drivers/hwmon/hwmon-lf1000.c).
# Test hook: POWER_DEV (event device) can be set from outside.

if [ -f /sys/devices/platform/lf2000-power/shutdown ]; then
  while true; do
    if [ "`cat /sys/devices/platform/lf2000-power/shutdown`" -eq "1" ]; then
      logger -s "Starting user-requested shutdown!"
      poweroff
      exit 0
    fi
    sleep 1
  done
fi

[ -f /sys/devices/platform/lf1000-power/shutdown ] || exit 0

BL=/sys/class/backlight/lf1000-pwm-bl/brightness
DARK=/tmp/.screen_dark_at
if [ -z "$POWER_DEV" ]; then
  N=`awk '/^N: Name="Power Button"/ {f=1} f && /^H: Handlers=/ {for (i=1;i<=NF;i++) if ($i ~ /event/) {sub("Handlers=","",$i); print $i; exit}}' /proc/bus/input/devices`
  [ -n "$N" ] && POWER_DEV=/dev/input/$N
fi

if [ -z "$POWER_DEV" ] || [ ! -e "$POWER_DEV" ]; then
  # fallback (first version): kernel flag, no wake-up detection
  logger -s "shutdown_monitor: Power Button input device not found, using the kernel flag"
  while true; do
    if [ "`cat /sys/devices/platform/lf1000-power/shutdown`" -eq "1" ]; then
      logger -s "Starting user-requested shutdown!"
      poweroff
      exit 0
    fi
    usleep 250000
  done
fi

# remember when the screen was last dark (gmenunx suspend writes brightness 0)
echo 0 > $DARK
( while true; do [ "`cat $BL 2>/dev/null`" = "0" ] && date +%s > $DARK; usleep 200000; done ) &

while true; do
  # one input_event = 16 bytes on 32-bit ARM: sec, usec, type(u16), code(u16), value(s32)
  set -- `dd if="$POWER_DEV" bs=16 count=1 2>/dev/null | od -An -tu2 -v`
  [ "$5" = "1" ] && [ "$6" = "116" ] && [ "$7" = "1" ] || continue
  now=`date +%s`; last=`cat $DARK 2>/dev/null || echo 0`
  if [ $((now - last)) -le 2 ]; then
    logger -s "Power pressed while the screen was dark: wake-up only, no shutdown"
    continue
  fi
  logger -s "Starting user-requested shutdown!"
  poweroff
  exit 0
done

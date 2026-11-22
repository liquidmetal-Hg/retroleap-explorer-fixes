# Retroleap alpha10 fixes for the Leapster Explorer (LF1000)

Fixes for [Retroleap](https://github.com/mac2612/retroleap) **v2.0.0-alpha10** on the **LeapFrog Leapster Explorer (LF1000)**. Without them, Game Boy saves are lost, the power button does nothing useful, and the OhBoy menu can't be opened.

> [!WARNING]
> **Reported 2026-11-20: no sound at all** on my Explorer after installing the v0.1 `ohboy` (built with `-O3`, with Vol +/- mapped to OhBoy's volume). Being investigated. Until then, keep a copy of your original `/usr/bin/ohboy` (step 1 below) so you can put it back.

> [!NOTE]
> **This is the `testing-s583b` branch: a newer OhBoy that is not released yet.** `main` and the v0.1 release are unchanged.
> - **The "no sound" report above was not OhBoy.** gmenunx had set the system volume so low (40 % = about -64 dB on the CS43L22) that it was silent.
> - **What `ohboy/patches/0005-sound-saves-speed-s583b.patch` adds** on top of 0001-0004:
>   - a reworked sound path (locked ring buffer, no busy-wait, audio errors logged, 16-bit mixing = less hiss)
>   - in-game saves written to flash a few seconds after the game saves
>   - safer save-state loading
>   - MBC5/RTC fixes
>   - stuck-button and menu fixes
> - **It is also much faster:** a table-driven tile decoder, a faster CPU core, unchanged frames not redrawn, and plain fullscreen frames written straight to `/dev/fb0` instead of through SDL's extra copy (`OHBOY_NODIRECT=1` turns that off).
> - **Measured on my Explorer, flat out, average of 9 games:** 9.1 ms per frame instead of 14.8 (Shantae 12.5 instead of 26.3; 16.7 ms = full speed). Picture and sound were identical to the old build in every test.
> - `OHBOY_BENCH=1 OHBOY_FRAMES=N` is a speed-test mode: no audio device, saves only in `/tmp`.
> - **Status:** speed-tested on the device and with offline tests only. **Not yet play-tested by a person** (menus, volume bar, screenshots, a normal session with sound). Use at your own risk, and keep your old `/usr/bin/ohboy`.
> - `./get_sources.sh && ./build.sh` in `ohboy/` builds it. The result should have sha256 `dc02550976e7515c8c139b8ce82f4b1addf0c716481e7e36d5c32a158075481a`. No prebuilt binary is attached for this branch.

**Status:** tested on **one** Leapster Explorer (factory firmware 1.3.4.2044 before flashing). Not tested on the LeapsterGS / LF2000; the LF2000 code paths are unchanged. This is a one-off share of what worked for me. There's no support and no release schedule.

Background and the full bug report: [DCFUKSURMOM/retroleap#2](https://github.com/DCFUKSURMOM/retroleap/issues/2), and [mac2612/retroleap#58](https://github.com/mac2612/retroleap/issues/58) (OhBoy never saves).

## What is fixed

| Problem in alpha10 | Fix | File |
|---|---|---|
| OhBoy never saves: `/roms/saves` is never created and the write fails silently (#58) | the folder is created at boot and by OhBoy itself | `S50mount_data_mtd`, OhBoy patch |
| `S50mount_data_mtd` has a broken test (`if [ -z ${BULK_PART}; then`, missing `]`) | fixed | `S50mount_data_mtd` |
| Power button ignored on LF1000 (`shutdown_monitor.sh` only knows `lf2000-power`) | reads the "Power Button" input device; a short press = clean power-off | `shutdown_monitor.sh` |
| Waking the dimmed screen with Power shuts the device down | a press while the screen is dark (or just went dark) only wakes it | `shutdown_monitor.sh` |
| Shutdown kills only retroarch, then unmounts `/roms` while OhBoy still runs, so its exit save is lost | stops the menu loop first, SIGTERM to emulators, waits up to 5 s, then `sync` | `S55start_menu` |
| OhBoy's menu needs Escape, which the Explorer lacks; Home is bound to `quit` | Home opens the menu; Vol +/- set the volume | OhBoy patch, `bindings.rc` |
| Saves are written in place, so an interrupted write destroys the old save | atomic writes: temp file, fsync, rename | OhBoy patch |
| No resume after power-off | automatic save-state on a clean exit, loaded on the next start of the same game (a broken state is moved aside, not retried) | OhBoy patch |
| "Apply & Save" writes settings where they are never read | written to `/configs/.ohboy/` | OhBoy patch |
| A/B differ between gmenunx, OhBoy's menu and the games | OhBoy menu: B = choose, A = back, like gmenunx | OhBoy patch |
| gmenunx dims the screen after at most 5 min (hard-coded limit) | optional: limit raised to 10 min | `tools/patch_gmenunx.py`, `gmenunx.conf` |

Each changed script has a short header saying what changed. `original-alpha10/` holds the same files as shipped, so `diff -r original-alpha10 overlay` shows every change.

## What is in this repo

```
overlay/                 changed text files, at their paths on the device
original-alpha10/        the same files from alpha10, for comparison
ohboy/patches/           0001-0003 = Retroleap's own OhBoy patches, 0004 = these fixes
ohboy/get_sources.sh     fetches OhBoy (hi-ban/ohboy @ 4720bcf) + Debian wheezy armel headers, checks sha256
ohboy/make_sysroot.sh    builds the cross-compile sysroot (needs an unpacked alpha10 rootfs)
ohboy/build.sh           cross-builds ohboy (Debian gcc-arm-linux-gnueabi, ARMv5TE soft-float)
ohboy/test_offline.sh    headless save/resume tests of the built ohboy in a chroot
tools/patch_gmenunx.py   one-instruction patch: gmenunx screen-off limit 300 s -> 600 s
tools/test_scripts.sh    offline tests of the init scripts with the image's own BusyBox
tools/make_patched_rootfs.py  copies alpha10's lf1000_rootfs.tar.gz with overlay/ files swapped in
```

A prebuilt `ohboy` is attached to the [release](../../releases), with its sha256. It is built from exactly these patches.

## Installing on a running Retroleap Explorer

You need SSH access to the Explorer as root (see the Retroleap docs). **Make a NAND backup first**, so you can go back to the factory firmware if something goes wrong.

1. Back up the files you will replace, on the device:
   ```sh
   mkdir -p /root/bak
   cp -a /etc/init.d/S50mount_data_mtd /etc/init.d/S55start_menu /usr/bin/shutdown_monitor.sh \
         /usr/bin/ohboy /configs/.ohboy/bindings.rc /root/bak/
   ```
2. Copy the files from `overlay/` to the same paths on the device, plus the prebuilt `ohboy` to `/usr/bin/ohboy` (`chmod 755` the scripts and `ohboy`).
3. Optional, 10-minute screen timeout: copy `/usr/share/gmenunx/gmenunx` from the device to your PC, run `python3 tools/patch_gmenunx.py gmenunx gmenunx.new` (it refuses any other build of gmenunx), copy `gmenunx.new` back as `/usr/share/gmenunx/gmenunx`, and use `overlay/configs/.gmenunx/gmenunx.conf`. Stop the menu first (`/etc/init.d/S55start_menu stop`). Note: the slider in gmenunx's settings still stops at 5 min; moving it sets the value back.
4. `sync`, then reboot.

Quick check after reboot: `/roms/saves` exists, and a short press on Power turns the device off cleanly. **A long press (2 s or more) is the kernel's hard power cut**: no save happens then.

Flashing a whole image instead: `tools/make_patched_rootfs.py <alpha10 lf1000_rootfs.tar.gz> <overlay dir> <out.tar.gz>` makes a copy of alpha10's rootfs with only these files replaced (owner and mode kept; it refuses files alpha10 doesn't have). Put the built `ohboy` (and the patched `gmenunx`, if you want it) into the overlay first.

## Building OhBoy yourself

Tested on a Raspberry Pi 5 (aarch64 Debian). It runs the Explorer's 32-bit ARM binaries natively, which is what the offline tests use. Needs `gcc-arm-linux-gnueabi`, `git`, `curl`, `dpkg-deb`.

```sh
cd ohboy
./get_sources.sh                          # OhBoy source + Debian debs, sha256-checked, patches applied
./make_sysroot.sh /path/to/unpacked/alpha10/rootfs
./build.sh                                # -> ohboy/build/ohboy (OPT=-O2 to change optimisation)
ROM=/path/to/game.gb ./test_offline.sh /path/to/unpacked/alpha10/rootfs
```

The binary links against the device's own glibc 2.18, SDL 1.2 and zlib (taken from the rootfs), and uses wheezy's glibc 2.13 headers. The highest symbol version it needs is `GLIBC_2.4`.

## How it was tested

- **OhBoy, offline** (chroot of the alpha10 rootfs, SDL dummy video and audio): 11/11 checks pass with a battery-backed GB game and a GBC game with 128 KB SRAM. The checks cover: save folder created, `.sav` written, auto save-state written and resumed, no save-state after a crash, a corrupt save-state not retried, and a failed write keeps the old save. **The original alpha10 binary fails 7 of the 9 save checks**, which reproduces #58.
- **Init scripts, offline** with the image's own BusyBox: all pass, including "power press while the screen is dark = wake only" and "shutdown lets OhBoy save".
- **On the real Explorer:** battery saves and auto-resume work, and a short power press shuts down cleanly.
- **Not yet confirmed on the device:** the final version of the wake-from-dark-screen handling, and the 10-minute screen timeout over a full 10 minutes.

## Known issues

- **No sound at all** with the v0.1 `ohboy` on my unit (reported 2026-11-20, being investigated; see the warning at the top). Before that, with the `-O2` build, audio stuttered at times.
- **Save files are dated 2008:** the Explorer's clock is not set, and Retroleap has no network time. Fix the clock with `date -s` over SSH.
- A long press on Power (2 s or more) is the kernel's hard power cut; nothing is saved then.

## Credits and licence

- [Retroleap](https://github.com/mac2612/retroleap) by mac2612 and contributors. The changed init scripts come from it.
- [OhBoy](https://github.com/hi-ban/ohboy) (based on gnuboy), and Retroleap's OhBoy patches 0001–0003.
- [gmenunx](https://github.com/podulator/gmenunx) for the launcher.

All of these are GPL-2.0, and so is this repo (see `LICENSE`).

**Disclosure:** made with AI assistance (Claude Code, with an independent review by Codex). Every finding was checked against the source code, and every fix was tested offline and then on the device.

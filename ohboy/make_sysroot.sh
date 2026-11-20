#!/bin/bash
# Recreate the OhBoy build sysroot. Inputs: sysroot-debs/*.deb (Debian wheezy armel, sha256 in
# sysroot-debs/SHA256SUMS, verified against the signed wheezy Release) + an unpacked alpha10 lf1000 rootfs.
# Headers + crt*.o + libc_nonshared.a come from wheezy (glibc 2.13); the shared libraries we LINK against
# (libc/ld/libm/libpthread/libdl/libgcc_s/libSDL/libz) are the device's own (glibc 2.18), so the binary
# can only need symbols the device really has.
set -euo pipefail
W=$(cd "$(dirname "$0")" && pwd)
RF=${1:?path to unpacked alpha10 lf1000 rootfs}
SR=${SR:-./work/ohboy-sysroot}
ML=arm-linux-gnueabi
(cd "$W/sysroot-debs" && sha256sum -c --quiet SHA256SUMS)
rm -rf "$SR"; mkdir -p "$SR"
for d in "$W"/sysroot-debs/*.deb; do dpkg-deb -x "$d" "$SR"; done
L=$SR/lib/$ML; U=$SR/usr/lib/$ML
for f in libc.so.6 ld-linux.so.3 libm.so.6 libpthread.so.0 libdl.so.2 libgcc_s.so.1; do cp -L "$RF/lib/$f" "$L/$f"; done
ln -sf libgcc_s.so.1 "$L/libgcc_s.so"
cp -L "$RF/usr/lib/libSDL-1.2.so.0" "$U/libSDL-1.2.so.0"; ln -sf libSDL-1.2.so.0 "$U/libSDL.so"
cp -L "$RF/usr/lib/libz.so.1" "$U/libz.so.1"; rm -f "$U/libz.so"; ln -sf libz.so.1 "$U/libz.so"
# libm.so / libpthread.so in wheezy are symlinks/scripts pointing at /lib/$ML/*.so.N -> now the device copies
echo "sysroot ready: $SR"

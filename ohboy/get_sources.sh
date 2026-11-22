#!/bin/bash
# Fetch everything the OhBoy build needs:
#  - OhBoy source (hi-ban/ohboy at 4720bcf, the commit Retroleap alpha10's ohboy.mk pins) -> src/, all patches in patches/ applied in order
#  - Debian wheezy armel dev packages (headers, crt files) from archive.debian.org -> sysroot-debs/, checked by sha256
set -euo pipefail
W=$(cd "$(dirname "$0")" && pwd)
if [ ! -d "$W/src" ]; then
  git clone https://github.com/hi-ban/ohboy "$W/src"
  git -C "$W/src" checkout -q 4720bcf5fbb4d80d85d6f623847d29cefea2cd94
  for p in "$W"/patches/*.patch; do patch -d "$W/src" -p1 < "$p"; done
fi
mkdir -p "$W/sysroot-debs"; cd "$W/sysroot-debs"
B=https://archive.debian.org/debian
for f in pool/main/e/eglibc/libc6_2.13-38+deb7u10_armel.deb pool/main/e/eglibc/libc6-dev_2.13-38+deb7u10_armel.deb \
         pool/main/libs/libsdl1.2/libsdl1.2-dev_1.2.15-5_armel.deb pool/main/l/linux/linux-libc-dev_3.2.78-1_armel.deb \
         pool/main/z/zlib/zlib1g-dev_1.2.7.dfsg-13_armel.deb; do
  [ -f "$(basename "$f")" ] || curl -fsSLO "$B/$f"
done
cp "$W/sysroot-debs.SHA256SUMS" SHA256SUMS
sha256sum -c SHA256SUMS
echo "sources ready"

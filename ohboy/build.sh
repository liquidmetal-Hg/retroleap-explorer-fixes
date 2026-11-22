#!/bin/bash
# Build OhBoy for the Leapster Explorer (LF1000, ARMv5TE soft-float, glibc 2.18 on device) on an aarch64 Linux host (tested: Raspberry Pi 5).
# Debian's arm-linux-gnueabi-gcc ignores --sysroot for libc, so libc/crt/headers are passed explicitly
# from a sysroot of Debian wheezy armel dev packages (glibc 2.13 <= device 2.18) + the device's own libSDL/libz.
set -euo pipefail
W=$(cd "$(dirname "$0")" && pwd)
SR=${SR:-./work/ohboy-sysroot}
OUT=${OUT:-$W/build}
CC=arm-linux-gnueabi-gcc
GCCINC=$($CC -print-file-name=include)
GCCLIB=$(dirname "$($CC -print-libgcc-file-name)")
ML=arm-linux-gnueabi
ARCH="-march=armv5te -mtune=arm926ej-s -marm -mfloat-abi=soft"
# -fno-strict-aliasing: gnuboy reads byte arrays through 32-bit pointers (patch 0005)
CFLAGS="$ARCH ${OPT:--O3} -fno-strict-aliasing -fno-pie -fcommon -std=gnu89 -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types -Wno-implicit-int -Wno-return-mismatch -nostdinc -isystem $GCCINC -isystem $SR/usr/include/$ML -isystem $SR/usr/include -I$SR/usr/include/SDL -D_GNU_SOURCE=1 -D_REENTRANT"
LIBDIRS="-L$SR/lib/$ML -L$SR/usr/lib/$ML -L$GCCLIB -Wl,-rpath-link,$SR/lib/$ML:$SR/usr/lib/$ML"
STARTS="$SR/usr/lib/$ML/crt1.o $SR/usr/lib/$ML/crti.o $GCCLIB/crtbegin.o"
ENDS="$GCCLIB/crtend.o $SR/usr/lib/$ML/crtn.o"
LDFLAGS="$ARCH -Wl,--as-needed -no-pie -nostdlib -Wl,--sysroot=$SR -Wl,--dynamic-linker=/lib/ld-linux.so.3 -Wl,--hash-style=sysv -s $LIBDIRS $STARTS"
LIBS="-lSDLmain -lSDL -lz -lm -lpthread -lc -lgcc -lgcc_s $ENDS"
cd "$W/src"
make -f Makefile.linux_sdl clean >/dev/null 2>&1 || true
# 'make clean' misses gnuboy/sys/sdl/*.o and gnuboy/unzip/*.o: delete every object file
find . -name '*.o' -delete
make -j4 -f Makefile.linux_sdl CC="$CC" LD="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" LIBS="$LIBS" STAGING_DIR="$SR" ohboy
mkdir -p "$OUT"; cp ohboy "$OUT/ohboy"
echo "built $OUT/ohboy"

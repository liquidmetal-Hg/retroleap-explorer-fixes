#!/bin/bash
# Offline test of the patched OhBoy on an aarch64 Linux host (tested: Raspberry Pi 5). A Raspberry Pi 5 (aarch64) kernel runs 32-bit ARM user code
# natively; a user-namespace chroot into a copy of the alpha10 rootfs gives the real /roms and /configs
# paths without root. SDL dummy video/audio = headless. Nothing here touches the Leapster.
set -u
W=$(cd "$(dirname "$0")" && pwd)
RF=${1:?unpacked alpha10 rootfs}
BIN=${BIN:-$W/build/ohboy}
ROM=${ROM:?set ROM=/path/to/a/battery-backed game.gb}
T=${T:-./work/ohboy-testroot}
rm -rf "$T"; cp -a "$RF" "$T"; cp "$BIN" "$T/usr/bin/ohboy"; chmod 755 "$T/usr/bin/ohboy"
mkdir -p "$T/roms" "$T/tmp" "$T/dev" "$T/proc"; cp "$ROM" "$T/roms/"; R=/roms/$(basename "$ROM"); N=$(basename "${ROM%.*}")
run() {  # run ohboy for $1 seconds, then send signal $2
  unshare -r -m -p -f --mount-proc /bin/sh -c "mount --rbind /dev '$T/dev' && mount -t proc proc '$T/proc' && exec chroot '$T' /bin/sh -c 'export HOME=/configs SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy; cd /usr/bin; /usr/bin/ohboy $R > /tmp/ohboy.log 2>&1 & p=\$!; sleep $1; kill -$2 \$p; i=0; while kill -0 \$p 2>/dev/null && [ \$i -lt 50 ]; do usleep 100000; i=\$((i+1)); done; kill -0 \$p 2>/dev/null && { echo STILL-RUNNING; kill -9 \$p; }; wait \$p; echo exit=\$?'"
}
pass=0; fail=0; check() { if eval "$2"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1"; fail=$((fail+1)); fi; }
S=$T/roms/saves
echo "== run 1: start, play 4 s, SIGTERM (= power button)"; run 4 TERM
[ -s "$T/tmp/ohboy.log" ] || [ -d "$S" ] || { echo "ABORT: ohboy did not run (no log, no savedir)"; exit 2; }
check "savedir /roms/saves created by ohboy" "[ -d $S ]"
check "battery save $N.sav written" "[ -s $S/$N.sav ]"
check "auto save-state $N.<cksum>.aut written" "ls $S/$N.??????.aut >/dev/null 2>&1"
check "no .tmp left over" "! ls $S/*.tmp >/dev/null 2>&1"
cp $S/$N.??????.aut "$T/tmp/aut1"
echo "== run 2: start again (must auto-load the state), SIGTERM after 4 s"; run 4 TERM
check ".aut consumed and kept as .aut.prev" "cmp -s $S/$N.??????.aut.prev $T/tmp/aut1"
check "new .aut written on second quit" "ls $S/$N.??????.aut >/dev/null 2>&1"
echo "== run 3: crash signal (SIGSEGV) must NOT write an auto-state"; rm -f $S/$N.??????.aut; run 3 SEGV
check "no .aut after crash" "! ls $S/$N.??????.aut >/dev/null 2>&1"
echo "== run 3b: corrupt auto-state -> consumed once, never retried"
cp $S/$N.??????.aut.prev "$T/tmp/goodprev"; A=$(ls $S/$N.??????.aut.prev); A=${A%.prev}; head -c 300 /dev/urandom > "$A"; run 3 TERM
check "corrupt .aut was moved away (not loaded twice)" "[ -s $A.prev ] && ! cmp -s $A.prev $T/tmp/goodprev"
rm -f "$A"; run 3 TERM; check "next start quits cleanly again (new .aut written)" "[ -s $A ]"
echo "== run 4: save dir not writable -> old .sav must survive"
cp "$S/$N.sav" "$T/tmp/sav_before"; mkdir "$S/$N.sav.tmp"   # a directory there makes the write fail, even as root
run 3 TERM; rmdir "$S/$N.sav.tmp"
check "write failure was reported in the log" "grep -q 'FAILED\\|cannot create' $T/tmp/ohboy.log"
check "old .sav unchanged when the write fails" "cmp -s $S/$N.sav $T/tmp/sav_before"
grep -h "FAILED\|cannot create" "$T/tmp/ohboy.log" | head -2
echo "== log of last run:"; tail -5 "$T/tmp/ohboy.log"
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env python3
"""explorer-fixes: raise gmenunx's screen-off (backlightTimeout) limit from 300 s to 600 s .
GMenu2X::readConfig -> evalIntConf(&confInt["backlightTimeout"], 30, 10, 300) is compiled as
  0xe430: e3a03f4b  mov r3, #300    (max)   0xe434: mov r1, #30 (default)   0xe438: mov r2, #10 (min)
Only that one instruction changes, to e3a03f96 = mov r3, #600. powerTimeout (next call) untouched.
The settings-menu slider still has max 300: changing the value there sets it back to <= 5 min."""
import sys, hashlib
src, dst = sys.argv[1], sys.argv[2]
d = bytearray(open(src, 'rb').read())
OFF = 0xe430
expect = {0xe430: 0xe3a03f4b, 0xe434: 0xe3a0101e, 0xe438: 0xe3a0200a}
for o, w in expect.items():
    got = int.from_bytes(d[o:o+4], 'little')
    if got != w: sys.exit(f"unexpected code at {o:#x}: {got:08x} (want {w:08x}); wrong gmenunx build")
d[OFF:OFF+4] = (0xe3a03f96).to_bytes(4, 'little')
open(dst, 'wb').write(d)
print("patched", dst, hashlib.sha256(d).hexdigest())

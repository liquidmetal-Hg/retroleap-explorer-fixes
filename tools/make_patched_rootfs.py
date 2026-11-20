#!/usr/bin/env python3
"""Copy alpha10 lf1000_rootfs.tar.gz, replacing only the files under overlay/.
Keeps every other member byte-for-byte and keeps owner/mode/mtime metadata of replaced members."""
import sys, tarfile, io, os, time
src, overlay, dst = sys.argv[1], sys.argv[2], sys.argv[3]
repl = {}
for root, _, files in os.walk(overlay):
    for n in files:
        p = os.path.join(root, n)
        repl["./" + os.path.relpath(p, overlay)] = open(p, "rb").read()
seen = set()
with tarfile.open(src, "r:gz") as tin, tarfile.open(dst, "w:gz", format=tin.format) as tout:
    for m in tin:
        if m.name in repl:
            data = repl[m.name]; m.size = len(data); m.mtime = int(time.time())
            tout.addfile(m, io.BytesIO(data)); seen.add(m.name)
        elif m.isfile():
            tout.addfile(m, tin.extractfile(m))
        else:
            tout.addfile(m)
missing = set(repl) - seen
if missing: sys.exit("NOT IN ARCHIVE (refusing to add new files): %s" % missing)
print("replaced:", *sorted(seen), sep="\n  ")

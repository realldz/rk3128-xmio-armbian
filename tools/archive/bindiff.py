#!/usr/bin/env python3
"""Compare two binary files: first diff offset + total differing bytes."""
import sys

def main(f1, f2):
    a = open(f1, 'rb').read()
    b = open(f2, 'rb').read()
    print(f"f1 size={len(a)} (0x{len(a):x})")
    print(f"f2 size={len(b)} (0x{len(b):x})")
    n = min(len(a), len(b))
    diffs = []
    i = 0
    first = None
    while i < n:
        if a[i] != b[i]:
            if first is None:
                first = i
            # collect diff region (coalesce within 4KB)
            if diffs and i - diffs[-1][1] < 4096:
                diffs[-1] = (diffs[-1][0], i + 1)
            else:
                diffs.append((i, i + 1))
        i += 1
    print(f"first diff at: {first} (0x{first:x})" if first is not None else "IDENTICAL in common prefix")
    print(f"diff regions (coalesced 4KB): {len(diffs)}")
    for (s, e) in diffs[:20]:
        print(f"  0x{s:08x}..0x{e:08x} ({e-s} bytes)")
    if len(a) != len(b):
        print(f"size delta: {len(b)-len(a)} bytes")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])

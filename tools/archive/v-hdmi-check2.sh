#!/bin/bash
# v-hdmi-check2.sh — verify shipping boot.img / resource.img contents
echo '=== md5 shipping files ==='
md5sum /workspace/output/planb-stock-uboot/boot.img /workspace/output/planb-stock-uboot/resource.img /workspace/output/planb-stock-uboot/rk3128-xmio-planb.dtb

echo
echo '=== boot.img header parse ==='
python3 - <<'EOF'
import struct, hashlib
p = "/workspace/output/planb-stock-uboot/boot.img"
d = open(p, "rb").read()
magic, ksize, kaddr, rsize, raddr, ssize, saddr, tags, psize = struct.unpack("<8I10I", d[:72])[:9]
print("magic:", d[:8], "pagesize:", psize)
print("kernel: size", ksize, "addr", hex(kaddr))
print("ramdisk: size", rsize, "addr", hex(raddr))
print("second: size", ssize, "addr", hex(saddr))
print("tags:", hex(tags))
name = d[72:88].rstrip(b"\x00").decode(errors="replace")
cmdline = d[88:600].rstrip(b"\x00").decode(errors="replace")
print("name:", repr(name))
print("cmdline:", repr(cmdline))
koff = psize
z = d[koff:koff+ksize]
print("zImage md5:", hashlib.md5(z).hexdigest(), "len", ksize)
print("zImage magic:", z[:4])
EOF

echo
echo '=== resource.img content (dtb parse via fdtdump-ish strings) ==='
python3 - <<'EOF'
import struct, hashlib
p = "/workspace/output/planb-stock-uboot/resource.img"
d = open(p, "rb").read()
print("resource md5:", hashlib.md5(d).hexdigest(), "len", len(d))
# resource header: magic 'RSCE' + version + entry count
magic = d[:4]
print("magic:", magic)
n = struct.unpack("<I", d[8:12])[0]
print("entries:", n)
off = 12
for i in range(min(n, 8)):
    tag = d[off:off+8].rstrip(b"\x00").decode(errors="replace")
    offs, sz = struct.unpack("<II", d[off+8:off+16])
    print(f"entry {i}: tag={tag!r} offset={offs} size={sz}")
    off += 16
EOF

echo
echo '=== SHA256SUMS.txt ==='
cat /workspace/output/planb-stock-uboot/SHA256SUMS.txt

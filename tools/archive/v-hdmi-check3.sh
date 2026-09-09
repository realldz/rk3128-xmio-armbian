#!/bin/bash
# v-hdmi-check3.sh — correct parse of boot.img + resource.img
echo '=== boot.img header (correct layout) ==='
python3 - <<'EOF'
import struct, hashlib
d = open("/workspace/output/planb-stock-uboot/boot.img", "rb").read()
print("md5:", hashlib.md5(d).hexdigest(), "size:", len(d))
magic = d[:8]
ksize, kaddr, rsize, raddr, ssize, saddr, tags, psize = struct.unpack_from("<8I", d, 8)
print("magic:", magic, "pagesize:", psize)
print(f"kernel: size={ksize} addr={kaddr:#x}")
print(f"ramdisk: size={rsize} addr={raddr:#x}")
print(f"second: size={ssize} addr={saddr:#x}")
print(f"tags: {tags:#x}")
name = d[48:64].rstrip(b"\x00").decode(errors="replace")
cmdline = d[64:576].rstrip(b"\x00").decode(errors="replace")
print("name:", repr(name))
print("cmdline:", repr(cmdline))
z = d[psize:psize+ksize]
print("zImage md5:", hashlib.md5(z).hexdigest(), "len:", len(z))
print("zImage magic:", z[:8])
EOF

echo
echo '=== resource.img unpack ==='
cd /tmp && rm -f resource.img.* && python3 /workspace/tools/pack_resource.py --unpack /workspace/output/planb-stock-uboot/resource.img
echo
echo '=== extracted dtb md5 vs shipped standalone dtb ==='
md5sum /tmp/resource.img.*.dtb /workspace/output/planb-stock-uboot/rk3128-xmio-planb.dtb 2>/dev/null

echo
echo '=== hdmi/vop/gmac/led nodes in extracted DTB ==='
DTB=$(ls /tmp/resource.img.*.dtb | head -1)
fdtdump -s "$DTB" > /tmp/planb.dts.txt 2>/dev/null || python3 - "$DTB" <<'EOF'
import sys, subprocess
subprocess.run(["dtc", "-I", "dtb", "-O", "dts", "-o", "/tmp/planb.dts", sys.argv[1]])
EOF
if [ -f /tmp/planb.dts ]; then
  echo "--- hdmi node ---"
  grep -n -A6 'hdmi@20034000' /tmp/planb.dts | head -20
  echo "--- vop status ---"
  grep -n -A2 'vop@' /tmp/planb.dts | head -12
  echo "--- gmac local-mac ---"
  grep -n -B2 -A2 'local-mac-address' /tmp/planb.dts | head -10
  echo "--- leds node ---"
  grep -n -A4 'xmio-leds\|status-led' /tmp/planb.dts | head -20
else
  echo "fdtdump/dtc output check /tmp/planb.dts.txt"
  grep -n -A6 'hdmi@20034000' /tmp/planb.dts.txt | head -20
fi

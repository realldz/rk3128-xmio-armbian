#!/bin/bash
# bootimg-dtb-check.sh — trích DTB (--second) tu boot.img hien hanh, so node gmac vs v23
set -uo pipefail
echo "=== tim file boot.img 5f61edcd ==="
for f in /workspace/output/planb-boot/boot.img /workspace/output/boot.img /workspace/output/planb-uboot-v5/boot.img; do
  [ -f "$f" ] && { echo "$f: $(md5sum "$f")  $(stat -c%s "$f")B"; }
done
ls /workspace/output/planb-boot/ 2>/dev/null
B=/workspace/output/planb-boot/boot.img
[ -f "$B" ] || B=$(find /workspace/output -name "boot.img" | head -1)
echo "DUNG: $B"
md5sum "$B"

echo
echo "=== parse Android bootimg header (page_size, kernel/ramdisk/second page counts) ==="
python3 - <<'PY'
import struct, subprocess, os
B="/workspace/output/planb-boot/boot.img"
if not os.path.exists(B):
    import glob; B=glob.glob("/workspace/output/**/boot.img", recursive=True)[0]
d=open(B,'rb').read(4096)
magic=d[:8]; print("magic:", magic)
ksize, kaddr, rsize, raddr, ssize, saddr, tags, psize, name, cmdline = struct.unpack("<10I", d[8:48])[0:10]
hdr = struct.unpack("<8I", d[8:40])
ksize,kaddr,rsize,raddr,ssize,saddr,tags,psize = hdr
print(f"page_size={psize} kernel={ksize}B({(ksize+psize-1)//psize}p) ramdisk={rsize}B({(rsize+psize-1)//psize}p) second={ssize}B({(ssize+psize-1)//psize}p)")
# cmdline at offset 64..64+512
cmdline = d[64:64+512].split(b'\0')[0].decode()
print("cmdline:", cmdline[:200])
kp = (ksize+psize-1)//psize; rp = (rsize+psize-1)//psize
sec_off = (2+kp+rp)*psize
out="/tmp/boot-second.dtb"
with open(B,'rb') as f:
    f.seek(sec_off); blob=f.read(ssize)
open(out,'wb').write(blob)
print(f"second extracted @0x{sec_off:x} size={ssize} -> {out}")
print("magic dtb:", blob[:4].hex())
PY

echo
echo "=== decompile + diff gmac/pinctrl vs v23 ==="
dtc -I dtb -O dts -o /tmp/boot-second.dts /tmp/boot-second.dtb 2>/dev/null && echo "dtc OK"
echo "--- node ethernet@2008c000 trong DTB SHIPPED:"
awk '/ethernet@2008c000 \{/,/^\t\};/' /tmp/boot-second.dts
echo "--- gmac pinctrl rmii-pins trong DTB SHIPPED:"
awk '/rmii-pins \{/,/^\t\t\};/' /tmp/boot-second.dts | head -14
echo
echo "=== DIFF toan bo DTB shipped vs v23 reference (chi ten node/thuoc tinh khac biet) ==="
dtc -I dtb -O dts -o /tmp/v23-res.dts /workspace/output/planb-resource/resource.img 2>/dev/null || \
  python3 -c "
import struct
# resource.img = header + dtb; tim magic d00dfeed
d=open('/workspace/output/planb-resource/resource.img','rb').read()
i=d.find(bytes.fromhex('d00dfeed'))
print('dtb magic at', i)
open('/tmp/v23-res.dtb','wb').write(d[i:])
" && dtc -I dtb -O dts -o /tmp/v23-res.dts /tmp/v23-res.dtb 2>/dev/null
diff <(sed 's/phandle = <[0-9a-fx]*>;//' /tmp/v23-res.dts | grep -v '^\s*$') \
     <(sed 's/phandle = <[0-9a-fx]*>;//' /tmp/boot-second.dts | grep -v '^\s*$') | head -60
echo "(empty diff = shipped DTB == v23)"

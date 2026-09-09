#!/usr/bin/env bash
# cleanup-output.sh — dọn output/ theo trạng thái hiện hành:
#   flash set: boot v24.1 + resource v24.1 + parameter NATIVE + uboot stock
#   + misc + baseparamer + miniloader + initrd + dtb + vendor-mac tool
#   Xoá: rootfs cũ (v15/v15j), SD 2G, chunk base64, test img, bundle cũ
#   Archive: các rollback (MAC-in-DTB resource, uboot-planb-mac, baselines)
set -uo pipefail
OUT=/workspace/output
PB=$OUT/planb-stock-uboot

before=$(du -sb $OUT | cut -f1)

echo "=== 0. diff parameter.txt hien tai vs native ==="
diff "$PB/parameter.txt" "$PB/parameter.txt.native" && echo "(identical)" || true

echo
echo "=== 1. ACTIVE: parameter.txt := native ==="
cp -f "$PB/parameter.txt.native" "$PB/parameter.txt"
md5sum "$PB/parameter.txt" "$PB/parameter.txt.native"

echo
echo "=== 2. xmio-led binary: giu v20.2 (md5 ee3fa38a...), bo v20.1 ==="
for f in "$PB/onbox/xmio-led-arm" "$PB/onbox/xmio-led-arm-v20.1"; do
  m=$(md5sum "$f" | cut -d' ' -f1)
  echo "$m  $f"
done
v202=0
for f in "$PB/onbox/xmio-led-arm" "$PB/onbox/xmio-led-arm-v20.1"; do
  m=$(md5sum "$f" | cut -d' ' -f1)
  if [ "$m" = "ee3fa38a5e624991a494cd84661a90c8" ]; then
    if [ "$f" != "$PB/onbox/xmio-led-arm" ]; then mv -f "$f" "$PB/onbox/xmio-led-arm"; fi
    v202=1
  fi
done
[ "$v202" = 1 ] && echo "v20.2 binary kept as onbox/xmio-led-arm" || echo "WARN: v20.2 md5 not found - keeping both"

echo
echo "=== 3. DELETE: stale / superseded / test ==="
rm -fv "$PB/onbox/chunkaa" "$PB/onbox/chunkab" "$PB/onbox/chunkac" \
       "$PB/onbox/chunkad" "$PB/onbox/chunkae" "$PB/onbox/xmio-led-c.b64" \
       "$PB/onbox/xmio-led-arm.gz"
rm -fv "$PB/boot-v23.img" "$PB/misc.img.bak" "$PB/initrd.img.gz.orig-A26"
rm -fv "$OUT/armbian_rootfs_v15_xmio.img" "$OUT/armbian_rootfs_v15_xmio.img.sha256"
rm -fv "$OUT/armbian_rootfs_v15j_xmio.img"
rm -fv "$OUT/xmio-sd-2g.img"
rm -fv "$OUT/XMIO-bundle.tar.gz"

echo
echo "=== 4. armbian_rootfs_26.2: duplicate cua A26-release? ==="
A26=/workspace/A26-release-20260430/A26-release-20260430/armbian_rootfs_26.2.img
if [ -f "$A26" ]; then
  m1=$(md5sum "$OUT/armbian_rootfs_26.2_xmio.img" | cut -d' ' -f1)
  m2=$(md5sum "$A26" | cut -d' ' -f1)
  echo "output: $m1"; echo "A26rel: $m2"
  if [ "$m1" = "$m2" ]; then
    rm -fv "$OUT/armbian_rootfs_26.2_xmio.img"
    echo "duplicate - deleted output copy (kept in A26-release)"
  else
    echo "DIFFERENT - kept both"
  fi
else
  echo "A26-release copy not found - kept"
fi

echo
echo "=== 5. ARCHIVE: rollback / historical ==="
mkdir -p "$OUT/archive"
mv -fv "$PB/resource.img.v23.2-mac.bak" "$OUT/archive/" 2>/dev/null
mv -fv "$PB/resource-baseline.img" "$OUT/archive/" 2>/dev/null
mv -fv "$PB/uboot-planb-mac.img" "$OUT/archive/" 2>/dev/null
mv -fv "$PB/parameter.txt.badnand1" "$PB/parameter.txt.v14diag.bak" \
       "$PB/parameter.txt.v16.bak" "$OUT/archive/" 2>/dev/null

echo
echo "=== 6. regen SHA256SUMS + bundle ==="
cd "$PB" && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.native misc.img baseparamer-720P.img \
  uboot-stock.img resource.img boot.img rk3128-xmio-planb.dtb \
  initrd.img.gz "rk3128MiniLoaderAll(L)_V2.25_ink.bin" \
  onbox/vendor-mac onbox/xmio-led-arm onbox/xmio-led.service > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'

cd "$OUT" && rm -f SHA256SUMS.txt
sha256sum armbian_rootfs_v22_xmio.img > SHA256SUMS.txt 2>/dev/null
[ -f armbian_rootfs_26.2_xmio.img ] && sha256sum armbian_rootfs_26.2_xmio.img >> SHA256SUMS.txt

bash /workspace/tools/bundle.sh
tail -2 /workspace/work/bundle.log

echo
after=$(du -sb $OUT | cut -f1)
echo "=== RESULT: $((before/1024/1024)) MB -> $((after/1024/1024)) MB (giam $(( (before-after)/1024/1024 )) MB) ==="
echo "--- planb-stock-uboot final ---"; ls -la "$PB" "$PB/onbox"
echo "--- output top-level final ---"; ls -la "$OUT" "$OUT/archive"

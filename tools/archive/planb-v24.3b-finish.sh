#!/usr/bin/env bash
# planb-v24.3b-finish.sh — verify phần còn lại + hashes + bundle
set -uo pipefail
IMG=/workspace/output/armbian_rootfs_v23_xmio.img

echo "=== 1. xmio-led-green da bien mat khoi rootfs? ==="
( debugfs -R "stat /usr/local/sbin/xmio-led-green" "$IMG" || echo "  -> GONE (usr/local/sbin)" ) 2>/dev/null | tail -1
( debugfs -R "stat /etc/systemd/system/xmio-led-green.service" "$IMG" || echo "  -> GONE (unit)" ) 2>/dev/null | tail -1
debugfs -R "ls /etc/systemd/system/sysinit.target.wants" "$IMG" 2>/dev/null | grep xmio \
  && echo "  !! van con trong sysinit.wants" || echo "  -> GONE (sysinit.wants)"
debugfs -R "ls /etc/systemd/system/multi-user.target.wants" "$IMG" 2>/dev/null | grep xmio \
  && echo "  !! van con trong multi-user.wants" || echo "  -> GONE (multi-user.wants)"

echo
echo "=== 2. armbian-led-state enabled o basic.target.wants (stock)? ==="
debugfs -R "stat /etc/systemd/system/basic.target.wants/armbian-led-state.service" "$IMG" 2>/dev/null | grep -E 'Inode|Type'
debugfs -R "ls -l /etc/systemd/system/basic.target.wants" "$IMG" 2>/dev/null | head -6

echo
echo "=== 3. conf da gieo dung chua ==="
debugfs -R "cat /etc/armbian-leds.conf" "$IMG" 2>/dev/null

echo
echo "=== 4. unit script van nguyen (save/restore) ==="
debugfs -R "stat /usr/lib/systemd/system/armbian-led-state.service" "$IMG" 2>/dev/null | grep Mode
debugfs -R "stat /usr/lib/armbian/armbian-led-state-restore.sh" "$IMG" 2>/dev/null | grep Mode
debugfs -R "stat /usr/lib/armbian/armbian-led-state-save.sh" "$IMG" 2>/dev/null | grep Mode

echo
echo "=== 5. hashes + bundle ==="
cd /workspace/output && rm -f SHA256SUMS.txt
sha256sum armbian_rootfs_v23_xmio.img > SHA256SUMS.txt
cd /workspace/output/planb-stock-uboot && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.native misc.img baseparamer-720P.img \
  uboot-stock.img resource.img boot.img rk3128-xmio-planb.dtb \
  initrd.img.gz "rk3128MiniLoaderAll(L)_V2.25_ink.bin" \
  onbox/vendor-mac onbox/xmio-led-arm onbox/xmio-led.service > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum /workspace/output/armbian_rootfs_v23_xmio.img
echo PLANB_V243B_DONE
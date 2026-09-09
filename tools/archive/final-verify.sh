#!/usr/bin/env bash
# Final integrity pass on BOTH deliverable images (after all patches).
exec > /workspace/work/final-verify.log 2>&1
set -e
mkdir -p /mnt/n /mnt/s

verify_root () {
  local M=$1 NAME=$2
  echo "===== $NAME ====="
  # 1. No competing boot targets (U-Boot prefers boot.scr.uimg over boot.scr;
  #    extlinux.conf would also be scanned by distro_bootcmd)
  if [ -e "$M/boot/boot.scr.uimg" ]; then echo "FAIL: boot.scr.uimg EXISTS"; else echo "OK: no boot.scr.uimg"; fi
  if [ -e "$M/boot/extlinux" ] || [ -e "$M/extlinux" ]; then echo "FAIL: extlinux exists"; else echo "OK: no extlinux"; fi
  # 2. boot.scr hook present (script data)
  local HOOKS
  HOOKS=$(tail -c +65 "$M/boot/boot.scr" | grep -c xmio_fdt_override || true)
  echo "hooks in boot.scr: $HOOKS"
  # 3. boot.cmd identical to our patch source
  diff -q "$M/boot/boot.cmd" /workspace/tools/boot-patch/boot.cmd >/dev/null && echo "OK: boot.cmd == boot-patch" || echo "FAIL: boot.cmd differs"
  # 4. DTBs present with expected sizes
  ls -la "$M/boot/dtb/rk3128-xmio.dtb" "$M/boot/dtb/rk3128-linux.dtb" 2>/dev/null | awk '{print $5, $9}'
  # 5. overlay dir count
  echo "overlays: $(ls "$M"/boot/dtb/overlay/*.dtbo 2>/dev/null | wc -l)"
  # 6. armbianEnv content
  echo "--- armbianEnv.txt ---"
  cat "$M/boot/armbianEnv.txt"
  # 7. kernel + uInitrd + modules version match
  ls "$M/boot" | grep -E '^(zImage|uImage|vmlinuz|uInitrd)' || true
  ls "$M/lib/modules" 2>/dev/null
  # 8. esp8089 module present?
  find "$M/lib/modules" -name 'esp8089*' 2>/dev/null || echo "no esp8089 module file"
  # 9. xmio-collect present
  [ -x "$M/usr/local/bin/xmio-collect" ] && echo "OK: xmio-collect" || echo "FAIL: xmio-collect missing"
  # 10. /etc/fstab root reference
  grep -v '^#' "$M/etc/fstab" | grep -E '^\s*[^ ]+' | head -3 || true
}

L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o ro "$L" /mnt/n; verify_root /mnt/n NAND-rootfs; umount /mnt/n; losetup -d "$L"

L=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
mount -o ro "$L" /mnt/s; verify_root /mnt/s SD-2G; umount /mnt/s; losetup -d "$L"

echo FINAL_VERIFY_DONE

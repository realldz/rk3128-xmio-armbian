#!/usr/bin/env bash
# v12-initramfs.sh — patch the initramfs for the rootfs-mount diagnosis.
#  1. 59-rknand-noblkid.rules: udev must NOT blkid-probe rknand* devices
#     (the FTL read path must only run from the root mount).
#  2. INITRD-DIAG echoes: udev trigger/settle milestones, device listing,
#     and a 1-sector probe read of rknand_root right before mountroot.
# Repacks output/planb-stock-uboot/initrd.img.gz (original kept as .orig).
set -euo pipefail
OUT=/workspace/output/planb-stock-uboot
W=/tmp/initrd-v12

[ -f "$OUT/initrd.img.gz.orig-A26" ] || cp -f "$OUT/initrd.img.gz" "$OUT/initrd.img.gz.orig-A26"

rm -rf "$W"
mkdir -p "$W"
gzip -dc "$OUT/initrd.img.gz.orig-A26" | cpio -idm -D "$W" 2>/dev/null
echo "unpacked: $(find "$W" -type f | wc -l) files"

# --- 1. udev rule: never blkid rknand* ---
cat > "$W/lib/udev/rules.d/59-rknand-noblkid.rules" <<'EOF'
# V12DIAG: skip blkid probing on rknand* block devices. The vendor FTL
# read path must only run from the root mount, not from udev workers.
KERNEL=="rknand*", ENV{UDEV_DISABLE_PERSISTENT_STORAGE_BLKID_FLAG}="1"
EOF
echo "OK   59-rknand-noblkid.rules"

# --- 2. INITRD-DIAG markers ---
python3 - <<'EOF'
import io

def patch(path, steps, guard):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        lines = f.readlines()
    if guard in "".join(lines):
        print("SKIP %s" % path)
        return
    for key, mode, new in steps:
        hits = [i for i, l in enumerate(lines) if key in l]
        if len(hits) != 1:
            raise SystemExit("FATAL: %s: %r hits %d" % (path, key, len(hits)))
        i = hits[0]
        if mode == "after":
            lines[i + 1:i + 1] = new
        elif mode == "before":
            lines[i:i] = new
        else:
            raise SystemExit("FATAL: mode %r" % mode)
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.writelines(lines)
    print("OK   %s (%d markers)" % (path, len(steps)))

patch("/tmp/initrd-v12/scripts/init-top/udev", [
    ("udevadm trigger --type=devices --action=add", "after",
     ['echo "INITRD-DIAG: udev trigger done"\n']),
    ("udevadm settle || true", "after",
     ['echo "INITRD-DIAG: udev settle done"\n']),
], "INITRD-DIAG")

patch("/tmp/initrd-v12/init", [
    ("mount_premount", "after", [
        'echo "INITRD-DIAG: mountroot begin"\n',
        'ls -la /dev/rknand* 2>&1 || true\n',
        'echo "INITRD-DIAG: probe read rknand_root (no OK line = FTL read hangs)"\n',
        'dd if=/dev/rknand_root of=/dev/null bs=512 count=1 2>&1 '
        '&& echo "INITRD-DIAG: probe read OK" '
        '|| echo "INITRD-DIAG: probe read FAILED"\n',
    ]),
    ("if read_fstab_entry /usr;", "before", [
        'echo "INITRD-DIAG: mountroot returned"\n',
    ]),
], "INITRD-DIAG")
EOF

# --- 3. repack ---
(cd "$W" && find . -print0 | cpio --null -o -H newc 2>/dev/null) \
  | gzip -9 > "$OUT/initrd.img.gz"
ls -la "$OUT/initrd.img.gz"
file "$OUT/initrd.img.gz"
echo V12_INITRAMFS_OK

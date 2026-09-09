#!/usr/bin/env bash
exec > /workspace/work/v18.2-analysis1.log 2>&1
echo '=== tune2fs available? ==='
which tune2fs e2fsck || { apt-get update -qq && apt-get install -y -qq e2fsprogs; }
which tune2fs e2fsck
tune2fs -V 2>&1 | head -1
echo
echo '=== rootfs images present ==='
ls -la /workspace/output/*.img | grep -iE 'rootfs|armbian'
echo
echo '=== features of each candidate ==='
for f in /workspace/output/armbian_rootfs_v15_xmio.img /workspace/output/armbian_rootfs_v15j_xmio.img /workspace/output/armbian_rootfs_26.2_xmio.img; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  tune2fs -l "$f" 2>&1 | grep -E 'Filesystem features|Filesystem state|Block count|Filesystem created|Last mount time' | head -6
done
echo
echo '=== C:\Temp\v15b.img equivalent? check workspace vol for copies ==='
ls -la /vol/*.img 2>/dev/null | head -5

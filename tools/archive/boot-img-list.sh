#!/bin/bash
# boot-img-list.sh — liet ke moi boot.img + md5 trong workspace
find /workspace -name "boot.img" 2>/dev/null | while read f; do
  printf "%-60s %s %10s B\n" "$f" "$(md5sum "$f" | cut -c1-32)" "$(stat -c%s "$f")"
done
echo "--- /vol side:"
ls -la /vol/kernel-out/arch/arm/boot/*.img* 2>/dev/null | head -5
find /vol -maxdepth 2 -name "boot*.img" 2>/dev/null | while read f; do
  printf "%-60s %s %10s B\n" "$f" "$(md5sum "$f" | cut -c1-32)" "$(stat -c%s "$f")"
done

#!/usr/bin/env bash
# One-shot acceptance test for the XMIO Armbian deliverables.
# Run after ANY rebuild: docker run --rm --privileged -v "${PWD}:/workspace" \
#   rk3128-build bash /workspace/tools/acceptance.sh
# Exit code 0 = all green. Log: /workspace/work/acceptance.log
exec > /workspace/work/acceptance.log 2>&1
FAIL=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; FAIL=1; }

echo "########## 1. Checksums ##########"
cd /workspace/output
N=$(sha256sum -c SHA256SUMS.txt 2>/dev/null | grep -c ': OK')
[ "$N" = "31" ] && ok "SHA256SUMS 31/31 OK" || bad "SHA256SUMS only $N/31"

echo "########## 2. Bundles ##########"
[ -f XMIO-bundle.tar.gz ] && ok "bundle exists" || bad "bundle missing"
NB=$(tar -tzf XMIO-bundle.tar.gz 2>/dev/null | wc -l)
[ "$NB" = "43" ] && ok "bundle 43 entries" || bad "bundle entries=$NB"
tar -tzf XMIO-bundle.tar.gz | grep -q boot-patch/boot.scr && ok "bundle has boot-patch" || bad "bundle lacks boot-patch"

echo "########## 3. Images ##########"
mkdir -p /mnt/n /mnt/s /tmp/merge
check_img () {
  local M=$1 LOOPDEV=$2 NAME=$3
  [ -e "$M/boot/boot.scr.uimg" ] && bad "$NAME boot.scr.uimg competes" || ok "$NAME no boot.scr.uimg"
  [ -e "$M/boot/extlinux" ] && bad "$NAME extlinux competes" || ok "$NAME no extlinux"
  H=$(tail -c +65 "$M/boot/boot.scr" | grep -c xmio_fdt_override || true)
  [ "$H" -ge 4 ] && ok "$NAME boot.scr hooks=$H" || bad "$NAME boot.scr hooks=$H"
  diff -q "$M/boot/boot.cmd" /workspace/tools/boot-patch/boot.cmd >/dev/null \
    && ok "$NAME boot.cmd matches patch" || bad "$NAME boot.cmd differs"
  [ -x "$M/usr/local/bin/xmio-collect" ] && ok "$NAME xmio-collect" || bad "$NAME xmio-collect"
  [ -f "$M/boot/dtb/rk3128-xmio.dtb" ] && [ -f "$M/boot/dtb/rk3128-linux.dtb" ] \
    && ok "$NAME both DTBs" || bad "$NAME DTBs missing"
  # fstab root UUID must match the actual fs UUID of this rootfs
  FSUUID=$(tune2fs -l "$LOOPDEV" 2>/dev/null | awk '/Filesystem UUID:/ {print $3}')
  FSTUUID=$(grep -oE 'UUID=[0-9a-f-]+' "$M/etc/fstab" | head -1 | cut -d= -f2)
  [ -n "$FSTUUID" ] && [ "$FSUUID" = "$FSTUUID" ] \
    && ok "$NAME fstab UUID matches fs ($FSTUUID)" || bad "$NAME fstab $FSTUUID != fs $FSUUID"
  echo "$FSTUUID" >> /tmp/uuids
  # module vermagic spot check
  V=$(modinfo -F vermagic "$M/lib/modules/6.6.89-rk3128+/kernel/drivers/net/wireless/rockchip_wlan/rkwifi/esp8089/esp8089.ko" 2>/dev/null | grep -c '6.6.89-rk3128+')
  [ "$V" = "1" ] && ok "$NAME esp8089 vermagic" || bad "$NAME esp8089 vermagic"
  grep -q esp8089 "$M/lib/modules/6.6.89-rk3128+/modules.dep" && ok "$NAME esp8089 in modules.dep" || bad "$NAME esp8089 not in dep"
  # env variant: presence/absence of uart2 overlay
  ENVUARTS=$(grep '^overlays=' "$M/boot/armbianEnv.txt")
  echo "$NAME overlays: $ENVUARTS"
}

rm -f /tmp/uuids
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o ro "$L" /mnt/n
check_img /mnt/n "$L" NAND-rootfs
umount /mnt/n; losetup -d "$L"

L=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
mount -o ro "$L" /mnt/s
check_img /mnt/s "$L" SD-2G
umount /mnt/s; losetup -d "$L"

NU=$(sort -u /tmp/uuids | wc -l)
[ "$NU" = "2" ] && ok "SD and NAND rootfs UUIDs are distinct" || bad "rootfs UUIDs not distinct ($NU unique)"

echo "########## 4. DT merge audit (NAND overlay set) ##########"
cd /tmp/merge
fdtoverlay -i /workspace/output/dtb/rk3128-xmio.dtb -o merged-nand.dtb \
  /workspace/output/dtb/overlay/rk3128-usb-otg-host.dtbo \
  /workspace/output/dtb/overlay/rk3128-uart1.dtbo \
  /workspace/output/dtb/overlay/rk3128-uart2.dtbo \
  /workspace/output/dtb/overlay/rk3128-dmc-disabled.dtbo \
  /workspace/output/dtb/overlay/rk3128-wlan-esp8089.dtbo
dtc -I dtb -O dts merged-nand.dtb > merged-nand.dts 2>/dev/null
cp merged-nand.dts /workspace/work/merged-nand.dts
grep -q 'vcc-host-vbus-hog' merged-nand.dts && ok "DT: vbus hog present" || bad "DT: vbus hog missing"
grep -A2 'vcc-host-vbus-hog' merged-nand.dts | grep -q 'gpios = <0x14 0x0' && ok "DT: hog gpio 0x14=PC4" || bad "DT: hog gpio wrong"
grep -A3 'vcc-host-vbus-hog' merged-nand.dts | grep -q 'output-high' && ok "DT: hog output-high" || bad "DT: hog not output-high"
# decompile loses labels: uart2 lives at serial@20068000 (RK3128 uart2 base)
awk '/serial@20068000/ {f=1} f && /status/ {print; exit}' merged-nand.dts | grep -q 'okay' && ok "DT: uart2 (serial@20068000) enabled" || bad "DT: uart2 not enabled"
grep -qi 'esp8089\|rk_wifi' merged-nand.dts && ok "DT: wifi node present" || bad "DT: wifi node missing"
grep -qE 'rknand|nandc@' merged-nand.dts && ok "DT: rknand/nandc node present" || bad "DT: rknand missing"

echo "########## 5. Kernel release / uInitrd ##########"
REL=$(cat /workspace/output/kernel/kernel.release)
[ "$REL" = "6.6.89-rk3128+" ] && ok "kernel release $REL" || bad "kernel release $REL"

echo "########## SUMMARY ##########"
if [ "$FAIL" = "0" ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
echo "ACCEPTANCE_DONE (FAIL=$FAIL)"
exit $FAIL

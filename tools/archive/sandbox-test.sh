#!/usr/bin/env bash
# Execute the patched boot.scr under a real U-Boot sandbox to prove hush
# syntax validity and hook behavior. Expects /vol/uboot-sb-build/u-boot ready.
exec > /workspace/work/sandbox-test.log 2>&1
set -x
SB=/vol/uboot-sb-build
cd /vol
rm -rf sbtest && mkdir sbtest && cd sbtest
# Fake storage: ubi.img (FAT via ubi? sandbox uses host fs binds; use mmc fake via
# 'fake mmc' requires driver; simplest: serve files via sandbox hostfs 'host' device)
mkdir -p boot/dtb/overlay
cp /workspace/tools/boot-patch/boot.scr boot/boot.scr
cp /workspace/output/dtb/rk3128-xmio.dtb boot/dtb/
cp /workspace/output/dtb/rk3128-linux.dtb boot/dtb/
cp /workspace/output/dtb/overlay/*.dtbo boot/dtb/overlay/
printf 'verbosity=1\nextraargs=coherent_pool=2M console=ttyS2,115200 console=ttyS1,115200 console=tty1\nbootlogo=false\noverlay_prefix=rk3128\nfdtfile=rk3128-xmio.dtb\noverlays=usb-otg-host uart1 uart2 dmc-disabled wlan-esp8089\nrootfstype=ext4\n' > boot/armbianEnv.txt
# kernel + initrd dummies (script will fail at load — fine; we only need parse + hook check)
echo fake > boot/zImage; echo fake > boot/uInitrd

cat > cmds.txt <<'EOF'
host bind 0 /vol/sbtest
setenv xmio_fdt_override rk3128-linux.dtb
setenv xmio_overrides "usb-otg-host uart1 dmc-disabled"
script load host 0:0 0x70000000 boot/boot.scr 2>&1
EOF
# 'script load' only loads; executing needs 'source'. Sandbox: use 'source 0x70000000'
cat > cmds.txt <<'EOF'
host bind 0 /vol/sbtest
setenv xmio_fdt_override rk3128-linux.test
setenv xmio_overrides "usb-otg-host uart1 dmc-disabled"
load host 0:0 0x70000000 boot/boot.scr
source 0x70000000
EOF
timeout 60 ./u-boot -T -c "$(tr '\n' ';' < cmds.txt)" > run1.log 2>&1 || true
echo "=== run1 (overrides set at prompt) — key lines ==="
grep -E '\[XMIO\]|\[DEBUG\] ========= Boot files|Error|error|Unknown command' run1.log | head -15

cat > cmds2.txt <<'EOF'
host bind 0 /vol/sbtest
load host 0:0 0x70000000 boot/boot.scr
source 0x70000000
EOF
timeout 60 ./u-boot -T -c "$(tr '\n' ';' < cmds.txt)" > run2.log 2>&1 || true
timeout 60 ./u-boot -T -c "$(tr '\n' ';' < cmds2.txt)" > run2.log 2>&1 || true
echo "=== run2 (no overrides) — key lines ==="
grep -E '\[XMIO\]|fdtfile|Error|error|Unknown command' run2.log | head -12
echo "=== parse errors anywhere? ==="
grep -ciE 'syntax error|unknown command|do_run_script' run1.log run2.log || echo ZERO_PARSE_ERRORS
echo SANDBOX_TEST_DONE

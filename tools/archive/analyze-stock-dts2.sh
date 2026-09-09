#!/usr/bin/env bash
D="$1"
echo "===== status of key nodes ====="
python3 - "$D" <<'EOF'
import re, sys
src = open(sys.argv[1]).read()
# find top-level nodes with names of interest and their status lines within
for pat in ['hdmi@20034000','tve@','lcdc@','vop@','rga@','usb@10180000','usb@101c0000','usb@101e0000',
            'dwc-control-usb@20008000','nandc@','nandc0@','sdmmc@','sdio@','emmc@','saradc@','adc@',
            'fiq-debugger','serial@','uart','pwm0@','pwm1@','pwm2@','pwm3@','i2c0@','i2c1@','i2c2@',
            'gmac@','dmc@','dram','dvfs','clk_vio','display-subsystem','display_subsystem','vpu@','hevc@','iep@','ion']:
    for m in re.finditer(r'^\t([a-zA-Z0-9_@-]*' + re.escape(pat) + r'[a-zA-Z0-9_@-]*)\s*\{', src, re.M):
        start = m.start()
        # crude brace matching
        depth = 0; i = src.index('{', m.start())
        j = i
        while j < len(src):
            if src[j] == '{': depth += 1
            elif src[j] == '}':
                depth -= 1
                if depth == 0: break
            j += 1
        body = src[m.start():j]
        st = re.findall(r'status\s*=\s*"([^"]+)"', body)
        print(f'{m.group(1):45s} status={st if st else "(none)"}')
EOF
echo "===== resolve phandles 0x95 (otg_drv), 0x75 (wifi gpio), 0xaa/0xab (pwm) ====="
grep -n -E 'linux,phandle = <0x95>|linux,phandle = <0x75>|linux,phandle = <0xaa>|linux,phandle = <0xab>' "$D"
echo "===== context around otg_drv_gpio ====="
grep -n -B3 -A3 'otg_drv_gpio' "$D"
echo "===== dvfs / voltage table ====="
grep -n -A8 'dvfs {' "$D" | head -40
echo "===== lcdc / screen config ====="
grep -n -E 'screen_type|lcdc|out_face|rockchip,prop|screen-on' "$D" | head -20
echo "===== wireless detail ====="
grep -n -B2 -A8 'wireless-wlan' "$D"

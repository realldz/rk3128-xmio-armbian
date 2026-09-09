# RK3128 XMIO Armbian — Workspace Notes

**Goal:** Build an Armbian image compatible with the RK3128 Android TV box (stock firmware
`VTIDC_XMIO_2016.01.28`, **NAND flash**). chieunhatnang-personal's A26 build boots (LED + LAN blinking)
but **no display, no USB** → suspected DTB/board mismatch with the XMIO hardware.
  (The stock Android firmware runs fully on the same box — display, USB, SD slot all
  work. Early "the XMIO has no SD slot" assumptions in this log are wrong and are
  corrected in place with [CORRECTED] markers.)

## 1. Resources in the workspace

| Path | Contents |
|---|---|
| `stock-firmware/update_(VTIDC_XMIO_20160128_for_nandflash).img` | Stock Android firmware (569MB, RKAF image for NAND) |
| `A26-release-20260430/A26-release-20260430/` | The author's Armbian 26.02 v1.1 build (currently running with issues) |
| `repos/` | The author's cloned repos (u-boot, kernel 4.4/6.6, scripts) |
| `docs/`, `tools/`, `work/` | Documentation, analysis tools, temporary build directory |

Contents of the A26 build (v1.1, 20260430):
`idbloader.img`, `uboot.img`, `trust.img`, `parameter.txt`, `rk3128_loader_v2.12.263.bin`,
`armbian_rootfs_26.2.img` (~1.08GB), kernel .deb `6.6.89-rk3128-24`, `bootcardmaker.sh`,
`build_kernel.sh`, `rk3128-armbian-cooking.sh`, `RKDevTool_v2.69/`.

`parameter.txt` (A26): `mtdparts=rk29xxnand:0x00002000@0x00002000(uboot),0x00002000@0x00004000(trust),-@0x00006000(root)`
→ the loader region is the first 4MiB; on NAND: uboot (4MiB) → trust (4MiB) → root (the remainder).

### NAND flashing procedure (verified from the author's blog)
- Parameter is written at address **0x0** (same spot as the miniloader — intentional, parameter is the input for miniloader).
- Loader partition = first 4MiB (0x0000–0x2000): Parameter / Partition table / MiniLoader / Parameter.
- RKDevTool 2.69: MaskROM → load the loader (`rk3128_loader_v2.12.263.bin`) → enters Loader mode →
  flash each file at its 512B sector address: parameter=0x0, uboot=0x2000, trust=0x4000, root=0x6000.
- The rknand driver creates `/dev/rknand_root` from the partition table; boot.cmd sets `root=/dev/rknand_root` automatically.
- Entering MaskROM: hold reset while plugging in power; if badly bricked: short NAND pins 16/17 (ALE/CLE) to GND — **never short D0**.

## 2. Key knowledge from the author's documentation

- Boot chain: BootROM → idbloader (ddr init + miniloader) → U-Boot → kernel → OS.
  - `idbloader.img` is written to **sector 64** of the boot media (SD/eMMC) — different from `rk3128_loader_vX.bin` (used for USB MaskROM flashing).
  - MaskROM mode: BootROM running, no DRAM yet → only the loader can be loaded via USB. Loader mode: DRAM available, flash freely (RKDevTool v2.69).
  - Entering MaskROM (NAND): hold the reset button while applying power, or short ALE/CLE (pins 16/17) to GND. **Never short D0.**
- The author's U-Boot boot order: **USB → SD → eMMC/NAND** → hybrid install
  (loader+uboot+trust on NAND, rootfs on USB OTG) or full NAND.
  [CORRECTED: the XMIO DOES have a working SD card slot — wrongly assumed
  missing here; SD is simply not used as a boot medium in the native layout,
  so the NAND-first install path stayed unchanged.]
- Kernel: 2 lines — 4.4.194 (vendor, stable) and 6.6.89 (what A26 uses). Main DTS: `rk3128-linux.dts`,
  overlays: `rk3128-*.dtbo` (usb-otg-host, uart1, wlan-*, emmc-enabled, dmc-*, cma-64m, v4l2-hantro...).
  Userspace Armbian 26.02 based on rk322x; board configured via `rk3128-config`, `/boot/armbianEnv.txt`.
- Notable point: **the blog never mentions HDMI/display bring-up** — meaning display works "out of the box"
  on the author's board (X11 + Lima runs) → the XMIO differs somehow in the display/power area.
- The blog emphasizes: RK3128 ≠ RK322x regarding DVFS (low voltage causes hangs); eMMC/SD/SDIO must use PIO
  (`rockchip,no-dmaengine`); the 6.6 rknand driver has the flush/discard fix (stable-1.1).

## 3. Hypotheses for the no-display / no-USB issue on the XMIO

1. DTB differs from the XMIO hardware: power (different vcc rails / pwm-regulator wiring), HDMI enable GPIO,
   i2c, pinctrl → kernel doesn't see HDMI/USB.
2. U-Boot doesn't match the XMIO's DRAM init (the ddr bin is shared across rk3128 but the miniloader parameters may differ) —
   but it already boots far enough that LAN blinks → DRAM init is almost certainly OK, the kernel is running.
3. Early kernel panic after boot (the LAN blink may come from the U-Boot PHY reset rather than Linux actually running).
   → Need a **UART log** to be sure. UART on RK3128 boxes is usually on pads on the board (uart2 dbg = 1500000 8N1,
   or uart1 — the A26 build uses uart1 for the console).
4. The XMIO stock firmware contains the board's correct DTB (in the `resource` / `kernel` partition) →
   **decode the stock firmware, extract the DTB/dts, compare it against the author's rk3128-linux.dts** to find the differences.

→ Plan: (a) analyze the stock firmware, extract the DTB + kernel config + the XMIO's original parameter;
(b) set up a Docker build environment; (c) build a kernel/DTB adjusted for the XMIO; (d) package the Armbian image;
(e) test via SD/hybrid.

## 4. Environment

- Docker Desktop 29.7.2 (linux/amd64), 8 CPUs, ~8GB RAM, ~45GB free disk.
- Build image: `rk3128-build` (tools/Dockerfile — Debian 12 + armhf cross toolchain + dtc, mkimage, afptool...).
- Container runs with `/workspace` mounted → this directory.

## 5. Stock firmware analysis (completed)

Firmware = RKFW v4.4.4 (2016-01-28); `rkunpack` (tools/bin/rkunpack) unpacks 2 layers:
`BOOT` (loader) + `embedded-update.img` (RKAF) → 14 parts: MiniLoaderAll(L)_V2.25_ink,
parameter-rk3128, uboot.img, misc, baseparamer-720P, resource.img, kernel.img, boot.img,
recovery.img, system.img, backup.img, scripts. Results in `work/stock-rkunpack/` and
`work/stock-dtbs/` (stock DTB decompiled: `rk312x-stock.dts`).

### Stock NAND layout (parameter-rk3128)
`uboot@0x2000(32MB?) ... kernel@0xE000(12MB), boot@0x14000, recovery, backup, cache,
userdata, system@0x28C000, upgrade, user` — cmdline console=ttyFIQ0 (fiq-debugger on UART2).

### XMIO board characteristics (from the stock DTB)
- **PWM regulator**: vdd_arm (pwm1, 0.95–1.45V, init 1.25V) + vdd_logic (pwm2, init 1.2V)
  → same architecture as the author's board. OPP arm: 408/1.1V(0xc7380=816MHz@0x10c8e0=1.1V?)...
  (further reading: operating-points kernel side)
- **HDMI**: node `hdmi@20034000` compatible `rockchip,rk312x-hdmi`, status okay; lcdc@1010e000
  okay; pinctrl hdmi hpd/sda/scl/cec. VOP/LCDC/HDMI use separate display ports (no vopl).
- **USB**: otg@10180000, ehci@101c0000, ohci@101e0000. **usb_control**:
  `host_drv_gpio = <&gpio3 20 1>` (GPIO3_C4), `otg_drv_gpio = <&gpio3 17 1>` (GPIO3_C1).
  ⚠ The 4.4 driver (usbdev_rk3126.c) uses raw gpio_set_value (ignores the polarity flag):
  host init forces 1 (5V ON), otg init forces 0 (5V OFF, power_enable(1)→1).
  → **VBUS host = GPIO3_C4 ACTIVE_HIGH is correct**; OTG uses GPIO3_C1 active-high
  (the author's base DTS is already correct, no polarity change needed).
- **WiFi**: ESP8089, poweren GPIO0_D6 (active high), host_wake GPIO0_A2 → **identical to**
  the author's wlan-esp8089 overlay.
- **Storage**: nandc@10500000 okay (raw NAND); sdio@10218000 okay (ESP8089); sdmmc disabled.
- **DVFS**: dvfs node with vd_arm/vd_logic — old-style vendor clk_core operating-points.
- **fiq-debugger** okay (console ttyFIQ0).

### Conclusion on XMIO vs the author's board differences
1. USB host VBUS GPIO3_C4 needs enabling (stock enables it; the base DTS lacks it) → **gpio-hog**.
2. The remaining differences appear minimal; a UART log is still needed to be sure about display.
3. The 6.6 HDMI/lcdc is based on rk312x.dtsi — the author already got display running on his board,
   and the XMIO is the same SOC family → display most likely just needs the correct DTB.

### Files added to the kernel repo (workspace)
- `arch/arm/boot/dts/rockchip/rk3128-xmio.dts` — dedicated XMIO DTS (includes rk3128-linux.dts,
  + gpio-hog GPIO3_C4 for the VBUS host, model name).
- `arch/arm/boot/dts/rockchip/overlay/rk3128-uart2.dts` — overlay enabling the UART2 console
  (SDMMC is unused in this NAND layout, so there is no uart2/sdmmc conflict;
  [CORRECTED: the XMIO does have an SD slot — the real reason `sdmmc` can stay
  off by default is the UART2 pinmux share, see FLASH-GUIDE C/Z.16]).
- Makefile: registered `rk3128-xmio.dtb` + `DTC_FLAGS_rk3128-xmio := -@`.

## 6. Build environment (set up)
- Docker image `rk3128-build` (Debian 12 + armhf toolchain + dtc/mkimage + rkdeveloptool).
- Toolchain GCC 10.3 (arm-none-linux-gnueabihf, YuzukiHD bundle) at `tools/toolchain/`.
- Docker volume `rk3128-build-vol` holds the toolchain + kernel source (ext4 — avoids the
  NTFS case-collision issue: xt_CONNMARK.h vs xt_connmark.h...).
  ⚠ The kernel working tree on NTFS is missing 3 files aux.c/aux.h + 6 case-collision files
  (none of them affect the ARM build if copied correctly via git archive from .git).
- `tools/bin/rkunpack` — unpacks RKFW/AF firmware.
- Known issue: the container cannot fetch from github (host is OK) → clone on the host, build inside the container.

## 7. Build results (2026-09-06)

- Kernel `6.6.89-rk3128+` built successfully with GCC 10.3 (arm-none-linux-gnueabihf):
  - `output/debs/linux-image-6.6.89-rk3128+_6.6.89-rk3128-2_armhf.deb` (zImage + dtb + overlays + modules)
  - `output/debs/linux-headers-...-2_armhf.deb`, `linux-libc-dev-...-2_armhf.deb`
  - `output/dtb/rk3128-xmio.dtb` (53KB) + 19 overlays (`output/dtb/overlay/`, including the new `uart2`)
  - `output/kernel/zImage`
- Rootfs repack successful: `output/armbian_rootfs_26.2_xmio.img` (1.08GB, ext4, fsck OK)
  - XMIO kernel + DTB + overlays; armbianEnv: `fdtfile=rk3128-xmio.dtb`,
    `overlays=usb-otg-host uart1 uart2 dmc-disabled wlan-esp8089`
- SD image: `output/xmio-sd-2g.img` (2GB: A26 bootchain + XMIO rootfs; the SD env had uart2 removed)
- NAND flash files: `output/nand-flash/` (parameter 0x0, uboot 0x2000, trust 0x4000, root 0x6000)

## 9. Verify results (round 1 goal)

- NAND rootfs image: vmlinuz/zImage/initrd/dtb/modules all `6.6.89-rk3128+` matching the A26 uInitrd;
  zImage + DTB hash-identical with the deb (f584383f…, 18bd77c8…).
- SD image: bootchain byte-identical to A26 (idbloader@64 = 1d35708b…, uboot@16384 = e54fe0c6…,
  trust@24576 = 4e61962c…); the ext4 partition at 16MiB mounts OK; the SD env had `uart2` removed
  (UART2 shares SDMMC pins on the RK3128 — boot.cmd automatically forces `sdcard-enabled` when booting from SD).
- `output/SHA256SUMS.txt` for all deliverables.
- Remaining: test on the real box (UART1 115200 → log; USB 5V; HDMI) — waiting on the user.

## 10. Round 2 goal — display analysis + A/B test readiness

- Compared the stock vs 6.6 display pipeline: stock (3.10 binding) `fb` + `lcdc@1010e000` +
  `hdmi@20034000` + **tve (CVBS) enabled**; 6.6 DRM: `&vop`/`&vop_mmu`/`&hdmi` (rk3128-inno-hdmi)
  all `okay` in rk3128-linux.dts with `route_hdmi` — **nothing missing in the DTB display path**.
- Reassessed the symptoms: the ethernet LED blink may just be PHY autoneg (hardware, no driver
  needed) → "no display + no USB" is very likely an early kernel panic, not a display-specific failure.
- Added an **A/B baseline**: compiled rk3128-linux.dtb (the author's, 52882B) and placed it next to
  rk3128-xmio.dtb in /boot/dtb of both the NAND rootfs + SD image → switch `fdtfile` via SSH
  or `setenv fdtfile rk3128-linux.dtb; boot` at the U-Boot prompt (UART) to isolate the fault.
- Considered a one-step update.img (RKFW): NOT doing it — the RKFW wrapper carries an MD5 that RKDevTool
  verifies, and the manual 4-file flash path per parameter.txt is already the author's standard procedure.
- Added to the guide: expected UART log per stage (the DDR banner may be on UART2, U-Boot on
  UART1, kernel after that).

## 11. Round 3 goal — voltages + diagnostic tooling

- Cross-checked stock vs 6.6 voltages: the stock PWM regulator range is 0.95–1.45V (min 0xe7ef0,
  max 0x162010), boot ~1.3V/1.2V; the author's OPP is 1.05–1.36V — fits well within the range,
  no risk of crashes from voltage scaling. The dtsi kernel-side OPP has a 1.05V floor
  (avoids dropping the 200MHz state because the PWM regulator cannot measure voltage below 1.05V).
- Stock additionally has tve (CVBS) + ADC button + IR — not required for boot; can be added later.
- Embedded `xmio-collect` (/usr/local/bin/xmio-collect) into both images: collects dmesg, USB,
  GPIO3, DRM/HDMI status, WiFi, cpufreq, lsblk, lsmod → /tmp/xmio-report.txt.
- New SHA256SUMS (31 files): rootfs=669e963e…, sd=31977d8e….

## 12. Round 4 goal — reproducibility

- `tools/rebuild-all.sh`: one-command pipeline (toolchain → git archive LF → kernel build →
  rootfs repack → baseline DTB → SD image → embed xmio-collect/fallback → SHA256SUMS).
- `README.md` at the workspace root: deliverables table, differences from A26, reproduction commands, structure.
- `tools/build_kernel.sh` = the patched version (TOOLCHAIN_DIR=/vol/toolchain), diff-identical
  to /vol/scripts/build_kernel.sh — the volume can be recreated at any time.
- bash -n passes for rebuild-all.sh.

## 13. Round 5 goal — end-to-end rebuild verification

- Actually ran `tools/rebuild-all.sh` start to finish in a privileged container: **REBUILD_EXIT=0**
  (toolchain → git archive → full kernel build ~20 minutes → rootfs repack → baseline DTB →
  SD image → embed → SHA256SUMS). The reproducible pipeline is proven by execution, not just syntax.
- Post-rebuild verification: both images contain rk3128-xmio.dtb + rk3128-linux.dtb + xmio-collect;
  the NAND env keeps uart2, the SD env drops uart2 automatically (make-sd-image.sh sed).
- `sha256sum -c SHA256SUMS.txt`: 33/33 OK (31 files + kernel.config + kernel.release).
- The deb version after the rebuild is `-1` (the counter reset when the build dir was deleted) — harmless.
- Conclusion: the offline part is closed out; every future iteration = a single rebuild-all.sh command.

## 14. Round 6 goal — simulating a real boot with fdtoverlay

- Ran `fdtoverlay` applying the exact overlay set from armbianEnv (what U-Boot does at boot) onto
  rk3128-xmio.dtb, decompiled the result and compared each node against the base:
  - UART2 `disabled` → `okay` in the merged NAND; stays `disabled` in the merged SD ✓
  - DMC `okay` → `disabled` in both (dmc-disabled) ✓
  - SDMMC `disabled` → full SD config (supports-sd, broken-cd, default-sample-phase 0x5a)
    only in the merged SD (boot.cmd forces sdcard-enabled) ✓
  - wlan-platdata `wifi_chip_type="esp8089"` ✓; GPIO3_C4 hog intact after the merge ✓
- Conclusion: the overlay chain works 100% correctly before touching hardware. fdtoverlay exit 0
  for both sets → __symbols__/__fixups__ complete in the DTB.
- Tool: tools/test-overlays*.sh (self-contained, logs to work/fdtoverlay-*.log).

## 15. Round 7 goal — 3-way console (UART1/UART2/HDMI)

- Discovery: `chosen stdout-path=serial1` + boot.cmd default `console=ttyS1,115200` +
  fiq-debugger disabled in rk3128-linux.dts → all logs go to UART1 only; the stock XMIO uses
  UART2 (fiq-debugger) → if the box's debug pads are UART2, the user will see nothing.
- Fix: armbianEnv extraargs = `console=ttyS2,115200 console=ttyS1,115200 console=tty1`
  → the kernel logs to all 3 paths (the kernel prints to every console= device; tty1 last = the
  primary console for init/HDMI). UART2 exists thanks to the uart2 overlay (NAND); on SD ttyS2 has
  no device → just a warning, harmless. The U-Boot banner still only comes out on UART1 (DEBUG_UART_BASE hardcoded).
- Patched into both images (tools/patch-console.sh) + fixed tools/repack-rootfs.sh so
  rebuild-all keeps the same configuration. New SHA256SUMS: 33/33 OK.
- Guide sections A + F updated.

## 16. Round 8 goal — rollback + cheat sheet

- Guide adds section H (recovery): (1) back to the original A26 = reflash the original armbian_rootfs_26.2.img
  to root@0x6000, bootchain untouched; (2) back to Android stock = RKDevTool 升级固件
  with the original stock RKFW; (3) root shell via
  UART (login root/1234); (4) U-Boot prompt 9s to setenv/printenv/saveenv.
- Section I: one-page cheat sheet of the procedure (USB-TTL → loader → 4 files → UART log → SSH →
  xmio-collect → USB/HDMI test).
- Verified paths: the original A26 rootfs + stock RKFW exist under the exact names.

## 17. Round 9 goal — hygiene + bundle

- Syntax check of 18/18 scripts in tools/ (bash -n) — all pass.
- Cleaned output/debs: dropped the 2 debs of version -1 (garbage from the validation rebuild), keeping only the -2 set
  matching the images. New SHA256SUMS: 31/31 OK.
- Created output/XMIO-bundle.tar.gz (36.7MB, 40 files): debs + dtb + overlays + kernel/zImage +
  nand-flash + SHA256SUMS + FLASH-GUIDE + README + NOTES — for moving machines/sharing without
  pulling the 2 large images (the rootfs 1.08GB + SD 2GB stay separately in output/).

## 18. Round 10 goal — boot order + recovery hook actually working

- Verified from the uboot.img binary: `boot_targets=usb0 usb1 mmc1 mmc0 rknand0 pxe dhcp`,
  `bootdelay=9`, prompt `RK3128 >>`, `boot_scripts=boot.scr.uimg boot.scr` (no .uimg
  → boot.scr is used), rknand_boot scan does not need the bootable flag. Guide confirmed correct.
- Bug found in the old guide D: `setenv fdtfile ...; boot` is INEFFECTIVE because boot.scr always
  `env import -t -r armbianEnv.txt` (read the source cmd/nvedit.c: -r = CRLF handling,
  does not delete variables; variables present in the file overwrite the values set at the prompt).
- Fix: add hooks to boot.cmd right after the import:
  `xmio_fdt_override` (swap the DTB once) + `xmio_overrides` (swap the overlay set once) —
  names not present in armbianEnv, so setenv values from the prompt are preserved.
  Recompiled boot.scr (mkimage legacy uImage, name "Armbian boot script for RK3128 boxes").
- Installed into both images (tools/patch-bootscr.sh, hook ×4 in the data) + tools/boot-patch/
  + rebuild-all.sh step 5 re-installs the hooks on every rebuild. SHA256SUMS 31/31, bundle 43 files.
- Minor incident: loop attach of the rootfs img briefly hit "Permission denied" (host-side transient
  lock) — cleared itself on retry; the SD image and test files attach normally.

## 19. Round 11 goal — trying the U-Boot sandbox + proving the patched boot.scr safe

- Goal: build `sandbox_defconfig` from the author's tree to **actually execute** the patched boot.scr
  (hush syntax test + hook behavior) on the host.
- Sandbox build result: FAIL after 6 rounds of fixes (uspinlock.h ARM-only → stub; SDL/SCMI off;
  CROSS_COMPILE leak from the Dockerfile env → `CROSS_COMPILE=`; CONFIG_DEBUG_UART_BASE/
  CONFIG_ROCKCHIP_BOOT_MODE_REG invisible in the sandbox Kconfig → had to pass -D via KCFLAGS;
  boot_mode.h stub) then hit `asm/arch/hotkey.h` (fdt_support.c) + `rk_atags.h`
  (cmd/atags.c) — the vendor tree invades generic code too deeply, porting the sandbox = a project of its own,
  cost >> benefit → STOPPED, leaving the sandbox-build3.sh/sandbox-test.sh tools in place as reference.
- Replacement safety proof (tight enough):
  1. `diff --strip-trailing-cr` of the original boot.scr data (extracted from boot.scr.orig) vs patched:
     **insertion-only** — 13 hook lines at `43a44,56`, NO original line modified/deleted →
     every remaining construct is identical to the script that really booted on the author's box.
  2. New constructs use only patterns already present in the original script: `if test -n "..."; then
     … fi` (like `if test -n "${rootpartname}"` line 67), `echo "..."`, `setenv x "${y}"`
     (like `setenv bootpart "${devnum}:${partnum}"` line 35).
  3. Data size: 9949 → 10498 (+549 = exactly the 13 hook lines); mkimage rebuilt from the very
     .cmd file that got installed, CRC verified by U-Boot itself at `source`.
- Technical lesson: the legacy uImage header of the mkimage container is **72 bytes** (64 + 8
  extension `00 00 26 dd ff ff ff ff`) — `tail -c +73` is where the real data starts; grep "hook ×4"
  is still correct because grep scans the whole data. `bash -n` is NOT valid for boot.cmd (hush accepts
  `()` inside a word — mtdparts — which bash rejects).
- Goal status: offline work is genuinely saturated; waiting for hardware testing on the box (UART log
  115200 + `sudo xmio-collect`) before any further data arrives.

## 20. Round 12 goal — final integrity pass + separating SD/NAND UUIDs

- Final verify of both images (tools/final-verify.sh → work/final-verify.log): **all OK** —
  no competing `boot.scr.uimg`/`extlinux` (U-Boot prefers .uimg if present — ruled out),
  hook ×4 in boot.scr of BOTH images, boot.cmd == boot-patch, DTBs of correct size,
  armbianEnv matches the variant (NAND has uart2 / SD dropped), esp8089.ko present in
  `drivers/net/wireless/rockchip_wlan/rkwifi/esp8089/`, module dir `6.6.89-rk3128+`,
  xmio-collect executable, fstab valid.
- Fixed a doc typo: overlays are **19** (not 20) — SHA 31 entries match:
  3 deb + 2 dtb + 19 dtbo + zImage + 4 nand-flash + 2 image = 31.
- boot.cmd Root= logic: SD/mmc uses **PARTUUID** (from the partition table), NAND uses
  `/dev/rknand_root` — the fs UUID does not affect boot, but both images previously shared
  fs UUID `f62d9d2c…` (copied from A26) → separated: SD `tune2fs -U random -L armbiands`
  (→ `5a6e4561…`) + sed the SD fstab to match; NAND keeps its matching fstab-UUID unchanged.
- Fix at the source in `tools/make-sd-image.sh`: future rebuilds generate their own UUID +
  patch the fstab (SDUUID → NEWSUUID), label `armbi_root` (NAND) vs `armbiands` (SD).
- Old guide line "setenv fdtfile …" (section H.4) switched to the `xmio_fdt_override` hook;
  README: added XMIO-bundle.tar.gz + boot-patch to the products table, noted 19 overlays,
  changelog entry #6 about the boot.scr hooks.
- SHA 31/31 OK, bundle 43 files (regenerated after the fstab fix). work/round12-final.log.

## 21. Round 13 goal — NAND root-device chain proven self-contained (source-level)

- Concern: `CONFIG_ROCKCHIP_RKNAND` "not set" — it turns out the real config name is **RK_NAND=y**
  (kernel.config line 6564), the driver lives in **drivers/rk_nand/** (THIRD — not
  drivers/mtd/rknand/ the legacy RK29 MTD-path, nor drivers/rkflash/).
- NAND boot chain proven end-to-end from U-Boot → kernel block device:
  1. uboot.img: `boot_targets` includes `rknand0` → boot.scr gets `devtype=rknand`.
  2. boot.cmd line 198-201: `rootdev=/dev/rknand_${nandrootpartname}` (default `root`).
  3. boot.cmd line 220 + fallback line 30: `mtdparts=rk29xxnand:0x2000@0x2000(uboot),
     0x2000@0x4000(trust),-@0x6000(root)` goes into the kernel cmdline.
  4. rk_nand_blk.c:668-684 `nand_parse_cmdline_part()` parses `mtdparts=rk29xxnand:…`
     from `saved_command_line` → creates named block devices: `rknand_uboot`,
     `rknand_trust`, **`rknand_root`** (line 750: `"%s_%s"` = `nand_ops->name` + part name;
     nand_ops->name = "rknand" in rk_nand_base.c:575).
  5. `CONFIG_RK_NAND=y` builtin — confirmed via `modules.builtin.modinfo` in the initramfs
     (entry `rk_nand_base.alias=rknand`); the initramfs needs NO rknand module/script.
- Conclusion: root=/dev/rknand_root can mount the NAND ext4 rootfs — no hidden dead spot.
- Additional report: the author's uInitrd (5.76MB, gzip cpio) contains NO module related
  to rknand — only builtin modinfo; the main drivers (STMMAC/DWMAC, DRM_ROCKCHIP, SND_SOC,
  USB EHCI/OHCI/DWC2, MMC_DW_ROCKCHIP, PWM_ROCKCHIP) are all **=y built-in** — display/USB/
  eth cannot fail from a missing module.
- vermagic: esp8089.ko + 50 sample modules are all `6.6.89-rk3128+ SMP mod_unload ARMv7 p2v8`
  matching our kernel (modules in the rootfs come from our debs via dpkg -x during repack);
  esp8089 is in modules.dep (depmod ran rw during repack).
- New tools: module-verify.sh, config-check.sh, rknand-probe.sh, uinitrd-probe.sh,
  builtin-probe.sh, zimage-probe.sh; logs in work/*.log.

## 22. Round 14 goal — one-command acceptance suite: ALL CHECKS PASSED (30/30)

- Console conflict audit: boot.cmd line 26 defaults to `console=ttyS1,115200` (armbianEnv
  does not define it) + our extraargs → bootargs contains console=ttyS1 … ttyS2 … ttyS1 …
  tty1 — the kernel prints to all 3 consoles, last primary = tty1 (HDMI). By design, no conflict.
- `tools/acceptance.sh` — run after EVERY rebuild, exit 0 = green:
  1. SHA256SUMS 31/31; 2. bundle 43 entries + boot-patch present;
  3. both images: no competing boot.scr.uimg/extlinux, hooks ≥4, boot.cmd == patch,
     xmio-collect, 2 DTBs, fstab UUID == fs UUID (tune2fs -l on the loop device),
     distinct SD/NAND UUIDs, esp8089 vermagic 6.6.89-rk3128+ + present in modules.dep,
     correct env variant (NAND has uart2 / SD dropped);
  4. DT merge audit (fdtoverlay positional args — NOT multiple -i): vbus hog PC4
     output-high, uart2 serial@20068000 okay, wifi node, rknand node;
  5. kernel release 6.6.89-rk3128+.
- Run result: **ALL CHECKS PASSED** (work/acceptance.log); merged DTS saved to work/merged-nand.dts.
- Traps noted: fdtoverlay takes overlays positionally (file string after -i/-o), decompiling
  with dtc loses labels (check by address: uart2 = serial@20068000, NOT 20078000),
  /tmp in the container does not survive across docker runs → copy artifacts out to /workspace/work.

## 23. Round 15 goal — HARDWARE FEEDBACK + Plan B (stock Android flow)

- Feedback from the user testing Plan A: **UART logs nothing, HDMI no signal, no LAN** —
  but when flashing just `uboot.img` FROM STOCK FIRMWARE, the UART outputs a full U-Boot
  2014.10-RK3128 log (miniloader OK, "check parameter success" — it can read
  the A26 parameter: warning "MACHINE_MODEL:RK3128_DEB" matching the A26 key).
- Conclusion: the A26 bootchain (uboot 2017 / trust) cannot run on this box
  (or it is a different UART console); the stock bootchain RUNS. The user's UART is wired correctly.
- Plan B — "stock flow, new contents": keep the stock Android boot mechanism,
  replace the contents with our Armbian. Built `output/planb-stock-uboot/`:
  - `parameter.txt`: stock-style partitions (uboot/misc/baseparamer/resource/boot/root
    @0x17000), Linux CMDLINE: console ttyS2+ttyS1+tty1, coherent_pool=2M,
    initrd=0x62000000,0x580000, root=/dev/rknand_root, mtdparts=rk29xxnand:…(root)
  - `uboot-stock.img` (1MiB) + `rk3128MiniLoaderAll(L)_V2.25_ink.bin` (stock loader)
  - `boot.img` (15.9MB): mkbootimg — kernel zImage 6.6.89 @0x60408000, initramfs
    (uInitrd with the 64B header stripped) @0x62000000 matching initrd=, second=resource.img
    (addr 0x60c08000, tags 0x60088000, pagesize 16384 — decoded from the stock boot.img header)
  - `resource.img`: hand-written packer (tools/pack_resource.py, RSCE/ENTR format
    per resource_tool.c: 512B header + 512B entry path[220]+hash[32]+III) containing
    rk3128-xmio.dtb under the NAME `rk-kernel.dtb` (the name stock U-Boot looks for); + variant
    `resource-baseline.img` (rk3128-linux.dtb) for A/B testing. Round-trip self-test OK,
    the stock resource parsed 3 entries (dtb+2 logo) confirming the format is right.
  - `misc.img` + `baseparamer-720P.img` stock copies kept intact.
- boot.img verify: ANDROID! header with the right fields; RSCE second blob at the right page offset;
  EXT4_FS=y builtin (the initramfs needs no ext4 module); rknand builtin (proven in
  §21); esp8089 vermagic matches (§21).
- Documentation: FLASH-GUIDE section J (complete flash address table: parameter 0x0,
  uboot 0x2000, misc 0x4000, baseparamer 0x6000, resource 0x6800, boot 0xE000,
  root 0x17000) + expected log output for each stage.
- A/B fallback: if Plan B is still silent → flash resource-baseline.img (author's DTB)
  in place of resource.img; if the kernel boots but USB/HDMI is broken → the UART log will show it
  and the DTS gets fixed from the log.
- **Important fix after review (same round)**: the second_offset I set initially
  (0x60C08000) WAS OVERLAPPED BY OUR KERNEL (kernel 10.1MB → 0x60408000-0x60DAE720,
  overlapping the second region) — stock uses 0x60F00000 because the stock kernel is only 6.9MB. Changed back
  to 0x00F00000 (kept exactly as stock) + added assertions that self-check the 3 RAM regions
  (kernel/second/ramdisk) for overlap in planb-bootimg.sh. Final layout: kernel 0x60408000-0x60DAE720,
  second 0x60F00000-0x60F0D400, ramdisk 0x62000000-0x6257D93E — no overlap, all 3
  addresses match original stock. Lesson: do not blindly copy second_offset — it must be computed from
  our own kernel_size.

## 24. Round 16 — root-cause analysis of "kernel silent after Starting kernel" + Plan B v3

- User flashed Plan B v2 → stock U-Boot log PERFECT: reads our boot.img (kernel
  0x9A6720=10,118,944B correct zImage size, ramdisk 0x57D93E=5,757,246B correct
  initramfs size), "Loading Device Tree to 6451c000 ... OK" (our FDT is loaded), then
  "Starting kernel ..." → SILENCE. Stock bootchain + Plan B format = working.
- Read the boot flow source (cmd/bootrkp.c 2017, ancestor of cmd_bootrk.c 2014 on the box):
  - bootrkp reads the KERNEL partition → kernel_addr_r (env, on the box = 0x62000000) and
    the BOOT partition (boot.img) as RAMDISK (→0x64bf0000). It does NOT use the kernel_addr
    of the boot.img header — the --kernel_offset is just metadata.
  - FDT: rockchip_read_dtb_file → from the resource partition (rk-kernel.dtb entry) or
    the second blob; images.ft_addr → do_bootm_linux(0,...) → arch/arm/lib/bootm.c
    boot_jump_linux: **r2 = ft_addr when an FDT exists — ATAGs are NOT passed**
    (kernel 6.6 takes everything via the DTB; ATAG_DTB_COMPAT is useless here).
- 2 fatal causes from the analysis (v3 build fixes both):
  1. **DTB missing /memory**: v2 has no memory node (the stock DTB leaves reg=<0 0> because
     older stock U-Boot does the fixup; bootrkp 2017 does NOT call fdt_fixup_memory when
     calling do_bootm_linux directly with flag=0). Kernel 6.6 boots with no valid
     RAM → dies before printing anything. v3: memory@60000000 reg=<0x60000000
     0x08000000> (128MiB — matches the box's DRAM log).
  2. **Console on the wrong port**: v2 chosen bootargs/earlycon targeted UART1 (0x20064000),
     stdout-path serial1; the user heard U-Boot on a different port (A26 also uses UART1
     and is silent — proving the port is not UART1). v3: earlycon on BOTH 0x20060000
     (UART0) and 0x20068000 (UART2), console=ttyS0/ttyS1/ttyS2/tty1,
     stdout-path serial2, ignore_loglevel; also enabled uart0 (stock fiq-debugger
     serial-id=0).
- More: dropped `initrd=` from the parameter CMDLINE — part_rkparm.c:109 actively filters
  `initrd=` when env-updating bootargs, and the real initrd sits at 0x64bf0000 (fdt_initrd
  writes the real linux,initrd-start/end into /chosen; 0x62000000 is now where U-Boot PUTS
  THE KERNEL — the kernel would reserve/unpack garbage if the cmdline still pointed there).
- Cmdline source: U-Boot takes the parameter CMDLINE → env bootargs → fdt_chosen writes it into
  /chosen (fdt_support.c:334 board_fdt_chosen_bootargs = env bootargs). The v3 DTB bootargs
  are only a fallback if the env is empty — console output is always available.
- v3 artifacts (output/planb-stock-uboot/, 9/9 checksum): parameter.txt (no
  initrd=), rk3128-xmio-planb.dtb (memory + 4 console paths), resource.img (v3
  DTB), boot.img (kernel/ramdisk/second as before, RAM layout verified), DTS saved at
  work/xmio-planb.dts. The dtc warning (phandle reference...) comes from the round-trip
  decompile/recompile of the vendor DTS — harmless for boot.

## 25. Round 17 — PSCI panic + Plan B v4 (SMP without ATF)

- v3 FLASHED SUCCESSFULLY: kernel 6.6 boots, earlycon UART0 (0x20060000) outputs the log,
  machine model correct, memory OK. PANIC right after:
  `psci: probing for conduit method from DT` → `__invoke_psci_fn_smc` →
  `Bad mode in prefetch abort handler`, PC=garbage, **Mode MON_32** (Monitor mode).
- Diagnosis: the /psci node (from the vendor dtsi, meant for the trust.img/ATF chain) makes
  the kernel issue SMC #0x84000000 (PSCI_VERSION); stock U-Boot 2014 has NO ATF —
  MVBAR points at garbage → jump to Monitor mode → abort. Plan B has no ATF → psci must be dropped.
- SMP-without-ATF analysis in platsmp.c (vendor 6.6):
  - CPU_METHOD_OF_DECLARE: "rockchip,rk3036-smp" (has_pmu=false — does NOT need
    a PMU node) and "rockchip,rk3066-smp" (needs the rk3066-pmu syscon — RK3128 has no
    such node → use rk3036-smp).
  - rockchip_boot_secondary: pmu_set_power_domain (has_pmu=false → only needs
    reset_control on the cpu node) + bootrom mailbox: sram+4=0xDEADBEAF,
    sram+8=secondary_startup, dsb_sev. SRAM taken from the node
    compatible="rockchip,rk3066-smp-sram".
- v4 DTB edits (tools/planb-v4.sh, DTS at work/xmio-planb-v4.dts):
  1. Delete the /psci node (match the \tpsci {...\t}; block).
  2. /cpus enable-method = "rockchip,rk3036-smp" (container level — the kernel reads
     it via of_cpu_device_node... in arch/arm/kernel/devtree.c).
  3. Per-cpu resets = <cru SRST_CORE0..3> — rk3128-cru.h: SRST_CORE0=4..CORE3=7
     (cru phandle 0x06 in the decompiled DTS).
  4. sram@10080000 (mmio-sram 8KB) + smp-sram@400 (reg <0x400 0x1c00>,
     holding pen 0x10080400 — matches stock 3.10 "rockchip,sram=sram@10080400";
     avoid the first 1KB since the bootrom uses it).
- Valuable observation from the v3 log: the kernel sees RAM [0x60000000-0x9fffffff]=1GB even though the node
  only declares 128MB → **stock U-Boot does fdt_fixup_memory itself from the dram bank**
  ("Add bank:0000000060000000(0000000040000000)" right before Starting kernel).
  Our /memory node is just a fallback. (The U-Boot banner "128 MiB" and the bank size
  0x40000000 contradict each other — trust the bank size: real DDR is 1GB.)
- dtc warning "not a phandle reference" (207/551 for the base/stock DTB): an artifact
  of the dtc 1.6.1 round-trip on the old vendor DTB (the v3 kernel resolves phandles fine —
  proven by earlycon + machine model). NOT a real error.
- v4 verified: no /psci, enable-method rk3036-smp, 4×resets <0x06 4..7>,
  smp-sram@400, memory node, layout OK, 9/9 checksum. Only resource.img + boot.img
  need reflashing (parameter unchanged).

## 26. Round 18 — v4 boots through PSCI, silent at the console handover + Plan B v5

- v4 FLASHED SUCCESSFULLY: no more panic! The kernel runs up to timekeeping:
  CPUs=4 (the SMP framework accepts 4 cores), arch_timer 24MHz, cmdline passed in
  intact (including mtdparts), CRU registration (warning "unknown clock type 12" =
  branch_ddrclk fails to register — harmless), then PRINTING STOPS at
  `console [tty1] enabled / bootconsole [uart8250] disabled`.
- Diagnosis: the handover happens at tty1 (vt console, no screen attached), and the 8250
  serial probe comes AFTER that point. From there printk has no real console → the UART is silent even
  if the kernel may still be alive. Cannot distinguish hung vs running-silent because earlycon is off.
- Potential issues checked (all OK):
  - pinctrl: DTB has "rockchip,rk3128-pinctrl" + "rockchip,gpio-bank" — both are
    in the of_match of pinctrl-rockchip.c 6.6 ✓
  - uart clock-names baudclk/apb_pclk ✓; 8250_DW=y, SERIAL_8250_CONSOLE=y ✓
  - NAND: CONFIG_RK_NAND=y (drivers/rk_nand, platform match "rockchip,rk-nandc"
    — DTB nandc@10500000 status okay ✓); rk_nand_blk.c creates disks per
    parameter part: "%s_%s" → "rknand_root" ✓ matches root=
  - CONFIG_MTD not set — RK_NAND is a separate block driver, no MTD needed ✓
- v5 (tools/planb-v5.sh — parameter.txt ONLY): add `keep_bootcon` (earlycon
  survives through the handover → see every initcall); move console=ttyS0 to the end
  (preferred console → /dev/console = ttyS0 for userspace). Checksums 9/9,
  bundle refresh. Flash parameter.txt→0x0 only.
- Expected v5 log: smp: Bringing up secondary CPUs (+CPU1-3 Booted or failed),
  pinctrl/gpio probe, serial probe, rknand probe → mount rknand_root → initramfs.

## 27. Round 19 — v5 progress + SMP mailbox bug + Plan B v6

- v5 FLASH: keep_bootcon works — ~40 more lines visible: initcalls up to
  the Bluetooth core (framework CONFIG_BT, not hardware), pinctrl 4 GPIO
  probed, ramoops/pstore, VOP+HDMI dependency cycle, SCSI/USB/ALSA...
- 2 findings:
  1. `smp: Brought up 1 node, 1 CPU` — secondary core does not boot. ROOT CAUSE:
     v4 set smp-sram@400 (per the stock 3.10 node sram@10080400 — just generic
     SRAM, NOT the mailbox). Bootrom mailbox has FIXED addresses
     0x10080004 (0xDEADBEAF) / 0x10080008 (entry) — every upstream dtsi
     (rk3036/rk3066/rk3188/rk3288) uses smp-sram@0 reg <0 0x10>.
     Kernel writes the flag into 0x10080404 → bootrom reads the fixed spot →
     empty → secondary core does not start.
  2. Last log line = "Bluetooth: SCO socket layer initialized" — the last
     initcall before the hang. initcall_debug added to name the real culprit.
- v6 (tools/planb-v6.sh): smp-sram@0 in the DTS (rebuild resource.img +
  boot.img), parameter + initcall_debug. Sanity OK, layout OK, 9/9, bundle OK.
- Flash: parameter.txt→0x0, resource.img→0x6800, boot.img→0xE000.

## 28. Round 20 — v6 catch the hang: rockchip_cpuinfo_init + Plan B v7

- v6 FLASH: initcall_debug works perfectly — the log details each initcall,
  ending at `calling rockchip_cpuinfo_init+0x0/0x18 @ 1` (no "returned")
  → HANG INSIDE that function. First time the hang is named precisely.
- Analysis of rockchip-cpuinfo.c: init = platform_driver_register; device
  `cpuinfo` (compatible rockchip,cpuinfo, nvmem-cells=efuse id@7) was populated
  by of_platform_default_populate_init → probe runs right inside register →
  nvmem_cell_read "id" → rockchip_rk3128_efuse_read (MMIO 0x20090000 +
  clk_bulk_prepare_enable pclk_efuse id 326 — gate valid in the 6.6 CRU) →
  silent hang: looks like infinite polling inside CCF/nvmem, no panic, no print.
- Other observations from the v6 log: (a) SMP still 1 CPU — no pr_err at all from
  platsmp (rstc valid, sram mapped, mailbox written to 0x10080004/8) but also
  no "CPU1: failed to come online" → cpu_up fails fast without printing;
  root cause not settled — doesn't block boot, shelved. (b) Timestamps all 0.000000
  and "after 0 usecs" — local_clock appears not to be running, keep an eye on it. (c) pinctrl
  4 GPIOs probed OK. (d) rockchip_soc_id_init (pure_initcall) runs but
  soc_id is not set (cpu_is_* depends on soc_id — chicken-egg; normally
  the cpuinfo probe would set it via efuse cpu-code — but we blacklist it →
  soc_id=0, vendor drivers gated on cpu_is_rk312x fall into the default branch).
- v7 (tools/planb-v7.sh — parameter.txt ONLY):
  `initcall_blacklist=rockchip_cpuinfo_init` — skip the culprit (cosmetic).
  Keep initcall_debug to catch the next hang if any. 9/9 checksum, bundle OK.
- Flash: parameter.txt→0x0 only.

## 29. Round 21 — v7 result: past cpuinfo, hang at the UART1 probe; Plan B v8

- v7 log analysis: `initcall rockchip_cpuinfo_init blacklisted` works;
  the kernel runs through hundreds of initcalls, initramfs unpacked (5624K), ext4/squashfs
  registered, `ttyS0 at MMIO 0x20060000 ... 16550A` OK, RGA/mpp-srv
  (hevc/vdpu/vepu -517=EPROBE_DEFER due to IOMMU dependency — normal),
  armv7 PMU, PL330 DMA, usb2phy (harmless IRQ ENXIO warning) probe OK.
- New hang: `probe of 20064000.serial:0` → `:0.0` → stop, NO ttyS1 banner
  → hang inside the dw8250 probe of UART1. UART0 completed right before
  (16550A banner printed) → confirms settling on console = UART0.
- v8 root cause: UART1/UART2 in the DTB are still `okay` from round one (copied from
  mainline default) while the box has nothing wired → v8 disables both +
  cleans up the cmdline: drop earlycon 0x20068000, ttyS1, ttyS2 — keep
  `earlycon 0x20060000 console=tty1 console=ttyS0 keep_bootcon
  initcall_debug initcall_blacklist=rockchip_cpuinfo_init ignore_loglevel`.
- tools/planb-v8.sh: v6.dts → v8.dts (python replace status in block
  serial@20064000/20068000), dtc compile, decompile sanity (uart0 okay,
  uart1/2 disabled, no psci, smp-sram@0, 4 cpu resets), repack resource.img,
  mkbootimg, parameter v8, layout assert, 9/9 checksum, bundle OK.
- Flash: parameter.txt→0x0, resource.img→0x6800, boot.img→0xE000.

## 30. Round 22 — v8 analysis: frozen timestamps = dead clocksource/sched_clock; Plan B v9 (timer-health + auto-bailout)

- v7/v8 observation: ALL printk lines are `[0.000000]`, every initcall `after 0 usecs`
  (even initcalls that genuinely take time). Ruling out a build artifact:
  `CONFIG_PRINTK_TIME=y` + printk uses the real `get_local_clock()`; initcall
  timing uses `ktime_get()` (init/main.c). Both read the same counter →
  the registered clocksource/sched_clock counter is NOT running.
- Source cross-check: jiffies still tick — boot gets past `calibrate_delay_converge`
  (`while (ticks == jiffies)`, calibrate.c:197) meaning the tick (clockevent)
  is ALIVE; while `after 0 usecs` + `[0.000000]` means clocksource/sched_clock
  is FROZEN. The only matching model: **CNTVCT (cp15 counter) dead because the bootchain
  stock (U-Boot 2014.10) does not enable the global arch counter; the tick survives only
  thanks to the DW-timer clkevt**; udelay/mdelay work because they are loop-based (no delay timer —
  register_current_timer_delay is not called by arm_arch_timer.c).
- Timer inventory (verify): the DTB has only 1 node `timer@20044000`
  (xin24m + PCLK_TIMER — exactly the standard mainline rk312x.dtsi). timer-rockchip.c:
  first node → clkevt (rating 250); only a second node → clksrc+sched_clock —
  with only 1 node the rk driver provides NO clocksource/sched_clock.
  Makefile link order: timer-rockchip.o (line 26) before arm_arch_timer.o (64).
  If the arch timer clockevent registers successfully (rating 400) it replaces DW as
  the local tick; with the counter frozen the event never fires → waits built
  on hrtimer hang forever → the hang point "drifts" to the first driver that hits
  a wait-timeout (v7: probe UART1; v8: tail probe UART0).
- Plan B v9 (kernel-only; DTB/parameter/resource unchanged → flash ONLY
  boot.img→0xE000):
  1. `include/linux/v9diag.h`: measure CNTFRQ, CNTVCT (mrrc p15,1 c14), DW timer
     CURRENT_VALUE0 (0x20044000+0x08), jiffies, sched_clock — twice around
     a pure 40M-iteration busywait (no tick/calibrate dependency); dump the CRU
     CLKGATE_CON0..14 (0xd0..0x108); open the SCLK_TIMER0..5 gates (CON10=0xf8,
     bits 3..8, write-enable high half) then restore the ctrl state unchanged.
  2. `arm_arch_timer.c arch_timer_of_init`: measure CNTVCT right at time_init;
     FROZEN → `return -ENODEV` (auto-bailout): the arch timer backs out cleanly
     (clockevent+clocksource+sched_clock), the DW-timer keeps the tick, sched_clock
     falls back to jiffies (kernel/time/sched_clock.c:243) → ktime survives at
     10ms granularity, no more dead ktime-waits.
  3. Trace 10 landmarks in dw8250_probe + uart_configure_port + 8250_core +
     serial_port.c + dw8250_do_pm + rockchip_boot_secondary → if it still hangs,
     the log itself points at the exact line.
- tools/v9-patch.py (idempotent exact-anchor, runs inside docker) +
  tools/planb-v9.sh (patch → make zImage incrementally in /vol/kernel-build →
  mkbootimg → layout assert → SHA256SUMS → bundle).
- Flash: **boot.img→0xE000 only**.
- Additional finding while verifying v9: `arch/arm/Makefile:218-220` of this tree is patched:
  `ifndef CONFIG_ARM_PSCI / machine-$(CONFIG_ARCH_ROCKCHIP) += rockchip /
  endif` — defconfig enables `CONFIG_ARM_PSCI=y` → **the whole mach-rockchip
  (rockchip.o + platsmp.o + headsmp.o) is NEVER built**. Consequence:
  (a) explains the 1-CPU SMP mystery across v4–v8 — there is no `rockchip_boot_secondary`,
  only the generic `psci_boot_secondary` in vmlinux; no /psci node →
  smp_ops NULL → cpu_up fails silently; (b) v9's platsmp trace is not in
  vmlinux (harmless). The SMP fix = v10: enable mach-rockchip (drop the guard or turn off
  CONFIG_ARM_PSCI) — DTB v6 already has smp-sram@0 + per-cpu resets in place.
  This can be fixed in the same v10 as the timer if v9 confirms the CNTVCT is frozen.

## 31. Round 23 — v9 log confirms the root cause; new panic = SIP SMC with no ATF; Plan B v10 (SIP stub + mach-rockchip SMP)

- **v9 log (hardware) locks in the timer root cause**: `V9DIAG[timer-of]: CNTFRQ=0
  CNTVCT 10385301642780608258 -> … (FROZEN)` (CNTFRQ is also =0 — the bootloader
  never touched the cp15 counter) → the bailout runs: `skipping arm_arch_timer`,
  `rk_timer clkevt registered freq=24000000`, `sched_clock: 32 bits at 100 Hz`
  → **timestamps are truly alive** (`0.010000 → 10.280000`), real initcall durations
  (dw8250 probe 800ms). The frozen-CNTVCT model matches perfectly; the v7/v8
  hang point = the moment the arch-timer clockevent (rating 400) wins the tick and then dies because
  the counter froze.
- v9 also proves **the UART0 probe passes all 10 stages cleanly** (`dw8250 probe-done`,
  `ttyS0 … is a 16550A`, console reregister OK) — not a UART fault.
- **New panic at 10.27s**: `Bad mode in prefetch abort … Mode MON_32 …
  LR is at __invoke_sip_fn_smc+0x54 … pc 0x4435b088 … r0: 82000009`, occurring
  right after `probe of display-subsystem returned 0`, BEFORE
  `rockchip_drm_init` prints `returned` → SMC 0x82000009 = **SIP_SHARE_MEM**
  (include/linux/rockchip/rockchip_sip.h:30) from the chain
  `rockchip_drm_init → rockchip_gem_get_ddr_info → sip_smc_get_dram_map →
  sip_smc_request_share_mem → __invoke_sip_fn_smc → arm_smccc_smc` (SMC
  instruction). No ATF → jump into Monitor mode via a garbage MVBAR → prefetch
  abort. This is the FIRST SMC actually executed in the whole boot (the v3 PSCI panic
  is the same in nature); SIP = a second "psci node" hidden in the code.
- **SMP still 1 CPU** — matches §30: the Makefile guard blocks mach-rockchip.
- **Plan B v10** (kernel-only; DTB/parameter/resource unchanged → flash
  ONLY boot.img→0xE000; md5 `2c103b69a1baea8e83899dc08bc35b6f`):
  1. `drivers/firmware/rockchip_sip.c __invoke_sip_fn_smc` → do NOT execute
     the SMC: `res.a0 = SIP_RET_SMC_UNKNOWN (-1)` + pr_warn
     `V10DIAG: blocked SIP SMC fn=0x%08lx`. Deliberately choosing -1 instead of faking
     success: if a0=0 were faked, `sip_smc_get_dram_map` would `memset_io(NULL)` →
     crash at address 0; with -1, `IS_SIP_ERROR`/`res.a0 != 0` makes every consumer
     (gem_get_ddr_info null-check; rk3128_dmc_init → -ENOMEM "no ATF memory
     for init", non-fatal) exit cleanly. Direct SMC callers outside
     `__invoke_sip_fn_smc` (rk3399/rk3528 dmc paths, clk-ddr SIP — not used
     by the rk3128 CRU, arm_smc_wdt has no DT node) never run on this board.
  2. Drop the `ifndef CONFIG_ARM_PSCI` guard in arch/arm/Makefile →
     mach-rockchip actually builds (verify in vmlinux: `__cpu_method_of_table_rk3036_smp`,
     `rockchip_boot_fn` trampoline, `rockchip_boot_secondary c0e849f4`,
     "Rockchip (Device Tree)"). SMP follows the enable-method `rockchip,rk3036-smp`
     of the DTB: rk3036_smp_prepare_cpus (has_pmu=false → NO PMU regmap needed
     — avoiding the "could not find pmu dt node" trap of the rk3066 path) → find
     `rockchip,rk3066-smp-sram` (the DTB has smp-sram@0 at SRAM 0x10080000) →
     ncores from the L2 aux reg → assert per-CPU resets (DTB: cru resets 4..7);
     boot_secondary: deassert reset → bootrom mailbox (sram+8 =
     secondary_startup, sram+4 = 0xDEADBEAF) → dsb_sev. pm.o/sleep.o also
     build (CONFIG_CPU_RK3288=y); at runtime rockchip_suspend_init only
     pr_errs "Failed to find PMU node" because the DTB has no rk3288-pmu — harmless.
  3. v9diag busywait 40M→8M loops (saves ~0.5s of diagnostic delay ×2 locations).
- Tools: `tools/v10-patch.py` (idempotent; two lessons learned:
  (a) the Makefile hunk must check idempotency by the absence of `old`, not
  the presence of `new`, because `new` is a substring already present in the guard;
  (b) `set -o pipefail` + `nm | grep -q` = SIGPIPE 141 makes a successful match
  get treated as a failure — use plain grep + >/dev/null).
  `tools/planb-v10.sh` = the v9 pipeline + verify symbols + repack boot.img +
  SHA256 9/9 + bundle. Analysis: `tools/v10-analysis1..7.sh` →
  `work/v10-analysis*.log`.
- Expected v10 log: `V10DIAG: rockchip machine init`, `rk3036
  smp_prepare_cpus done ncores=4`, `blocked SIP SMC fn=0x82000009`,
  `smp: Brought up 1 node, 4 CPU`, then boot continues to the rootfs. The three
  log-interpretation branches are recorded in FLASH-GUIDE section R.
- Infrastructure: the docker container `rk3128-build` once disappeared after a reboot — recreate
  it with `docker run -d --name rk3128-build --privileged -v
  rk3128-build-vol:/vol -v <workspace>:/workspace rk3128-build sleep infinity`
  (image + volume still intact).

## 32. Round 24 — v10 BOOTS INTO ROOTFS (user confirmed); v10.1 drops keep_bootcon, x2 log lines gone

- **Milestone**: the user flashed v10 `boot.img`→0xE000 → boot reaches the rootfs
  successfully. The root-cause chain (frozen CNTVCT → bailout; SIP SMC → stub;
  mach-rockchip → SMP) all landed.
- Log spam, 2 lines per message: the cmdline has `keep_bootcon` keeping earlycon (the bootconsole
  uart8250) alive alongside the real `ttyS0` → every printk message goes out through both
  consoles (the tell: `printk: debug: skip boot console de-registration.`
  and x2 after `console [ttyS0] enabled`).
- **v10.1**: `parameter.txt` drops `keep_bootcon` (keep earlycon so there is still output
  before ttyS0; once ttyS0 registers, the kernel turns the bootconsole off by itself). Flash only
  `parameter.txt`→0x0; sha256
  `27d704285dc5b1a0f90d7f46f46fbd5d2634dadac6b1d767fead01922497e092`;
  boot.img stays at v10. `initcall_debug`/`ignore_loglevel`/`earlycon`
  kept for the next HDMI/USB debug round, to be dropped in the final release build.
- Remaining work to complete the goal: confirm 4 CPUs + HDMI + USB + eth from the log/
  shell; clean out the instrumentation (V9DIAG/V10DIAG) for the release; merge the DTB
  v6–v8 + kernel fixes into the main Armbian chain (rootfs /boot/dtb +
  boot-patch + debs).

## 33. Round 25 — v10.1 x2 gone; rootfs hangs in initramfs waiting for /dev/rknand_root; v11 = V11DIAG rk_nand chain + rootdelay=60

- The user confirms v10.1 (keep_bootcon dropped) is free of the x2 log lines. The log stops at
  `Loading, please wait...` + `Starting systemd-udevd 252.39-1~deb12u1`
  = **initramfs-tools** (not the real systemd yet — systemd will print
  "Welcome to Armbian" + the `systemd[1]` banner). It is waiting for the root device
  `/dev/rknand_root`; the cmdline has `rootwait` → it waits forever silently,
  without dropping to a shell.
- Static investigation (v11-analysis1..6):
  - `.config` line 6564 `CONFIG_RK_NAND=y`; vmlinux HAS the symbols
    (`rk_ftl_init c0a718a4`, `rknand_probe c0a85014`,
    `rknand_dev_init c143130c`), strings `rk29xxnand:`,
    `rockchip,rk-nandc`; modules.builtin line 463. The driver is built-in
    from the original .config at 10:06 (not something I enabled).
  - `drivers/rk_nand/` = the vendor block driver already ported to 6.6 (blk-mq):
    `rk_nand_blk.c` parses `mtdparts=rk29xxnand:...` from
    saved_command_line (prefix "rk29xxnand:" after "mtdparts="), disk
    name = `mytr.name("rknand") + "_" + partname` → `rknand_root`,
    major 31, minorbits 0. FTL = asm blobs (rk_zftl_arm32.o +
    rk_ftlv5_arm32.o because CONFIG_THUMB2_KERNEL=n).
  - Init chain: `of_platform_default_populate_init` (3s) creates the platform
    device nandc@10500000 → `rknand_driver_init` (level 6, initcall
    c14a4c5c AFTER rockchip_drm_init — which is why v9 panics BEFORE drm, so
    rknand never got a chance to run) → platform_driver_register → sync probe →
    rknand_dev_init → rk_ftl_init → nand_blk_register.
  - **Silent death paths**: probe `boot_media==2 → return -1` (no
    print); `rknand_dev_init` with `nandc0 NULL → return -1` (no
    print); a `rk_ftl_init` failure does print "rk_ftl_init fail".
  - The kernel already reached the late initcalls (ALSA 22.87s) → rknand init
    had finished running (ok or fail) BEFORE /init — if the disk is
created successfully the initramfs must see it right away. A hang =
almost certainly the disk was NOT created.
- **v11** (flash boot.img→0xE000 + parameter.txt→0x0):
  1. `tools/v11-patch.py` (line-based, idempotent by "V11DIAG in
     file"): 7 V11DIAG points — probe enter (id), idb magic +
     boot_media_raw (wrapping the silent return -1 path), probe done,
     nandc0/nandc1 %px, nandc0 NULL now PRINTED, rk_ftl_init ok +
     capacity sectors/MB, nand_blk_register ok + parts count.
     Lesson: replace_span only checks the key on the FIRST line of the span (first
     version also checked the next line → wrongly FATAL).
  2. `parameter.txt`: `rootwait` → `rootdelay=60` — if the root device
     does not appear within 60s, initramfs-tools drops an emergency shell
     `(initramfs)` over UART (last console = ttyS0) instead of hanging silently.
  3. Verify build: strings V11DIAG ×4 + nm rk_ftl_init; boot.img
     repack + layout assert + SHA256 9/9 + bundle.
- Next step: read the v11 log along 4 branches (FLASH-GUIDE item T): NAND alive
  up to systemd / probe dies midway (last line = point of death) / no
  V11DIAG (suspect the nandc node is taken over by the mainline NFC node at the same address
  10500000, or an hclk defer) / emergency shell → type
  dmesg/ls /dev. The mainline NFC node `nand-controller@10500000`
  (rk3128-nfc/rk2928-nfc) is harmless for now because CONFIG_MTD is fully off
  (.config has no CONFIG_MTD).

## 34. Round 26 — v11 log: NAND 100% HEALTHY up to parts=6; root cause = FTL blob race (GC vs vendor-storage); v12 disables background GC + avoids blkid

- v11 log (user): the whole rknand chain healthy — `probe enter id=0`, `idb
  magic 0x44535953 boot_media_raw 1` (NOT boot_media 2!), clk
  148.5MHz, `FLASH ID: 98 d7 84 93 72 50`, `ECC:60`, `FTL version
  5.0.63`, `ftl_init 0`, `rk_ftl_init ok capacity 7667712 sectors
  (3744 MB)`, table of 6 partitions (root 3698MB), `nand_blk_register ok
  parts=6` @17.65s, initcall returned 0 after 5.57s. `/dev/rknand_root`
  existed BEFORE /init. Boot still silent after `Starting systemd-udevd`.
  (log also confirms SMP not yet up — only "calling ... @ 1"; will inspect later)
- Analysis (v11-analysis7..8):
  - `/scripts/init-top/udev`: udevd --daemon → `udevadm trigger
    (subsystems, devices)` → `udevadm settle || true`. The next line
    in /init (`Begin: Loading essential drivers`) never prints
    → hang inside settle.
  - `60-persistent-storage.rules:128`: `IMPORT{builtin}="blkid"` on
    every block device (except sr*/mmcblk*boot*) → blkid reads the superblock
    of rknand_* inside a udev worker → kernel holds `g_rk_nand_ops_mutex`
    (mutex, rk_nand_blk.c:150) for the entire FTL read.
  - `nand_gc_thread` kthread_run @17.66s with `rk_ftl_gc_do=1` right from
    the start → `rk_ftl_garbage_collect(1,0)` into the FTL blob (rk_zftl_arm32.o
    / rk_ftlv5_arm32.o — vendor assembly, state machine not
    re-entrant) AT THE SAME TIME `rk_ftl_vendor_storage_init()` (which also calls
    the blob) is still running @17.0–17.65s → the lines `ReadRetry pageadd=...
    ecc=28 err=ffffffff` + `rknand vendor storage init failed !` are
    evidence of the conflict. The blob gets stuck holding the mutex forever → every read (blkid)
    blocks forever → settle waits forever → permanent silence.
  - Kernel read path: queue_rq → rk_nand_blktrans_work (loop, unlock
    queue_lock while FTL runs) → device_lock → do_blktrans_all_request
    → blob; NO timeout — a stuck request = hard hang. `rootdelay`
    in /init only sleeps AFTER init-top/udev (does not help).
- **v12** (boot.img only; parameter keeps rootdelay=60):
  1. `tools/v12-patch.py` (line-based, idempotent by V12DIAG):
     `rk_ftl_gc_do = 0` at thread start + at queue_rq (background GC fully
     disabled — REQ_FUA/flush still `rk_ftl_cache_write_back`); counters
     `v12_rq_count`/`v12_gc_count`; print the first 8 requests (`rq start
     dev=... sec=... nsec=...` / `rq done res=...`) and GC enter/done.
     API note: `req->q->disk->disk_name` (not disk_name()).
  2. `tools/v12-initramfs.sh` (the original initrd saved as
     `initrd.img.gz.orig-A26`): rule `59-rknand-noblkid.rules` (set
     UDEV_DISABLE_PERSISTENT_STORAGE_BLKID_FLAG for `rknand*` —
     60-persistent-storage.rules:118 already GOTOs past blkid when the flag is set);
     INITRD-DIAG echo after trigger/settle; `dd` probe of 1 sector
     of rknand_root before mountroot (`probe read OK` = read path alive).
  3. `tools/planb-v12.sh`: build + verify V12DIAG/V11DIAG strings +
     initramfs repack + mkbootimg + layout + SHA + bundle.
- v12 log result (Round 27): NO rq start at all + NO
  trigger-done marker → FTL hypothesis refuted → see §35 (1-timer race).
- Pipeline lesson: a build script that generates files in /tmp (initramfs) must
  be a separate .sh file (v12-initramfs.sh) because docker exec -i uses python stdin
  when a complex heredoc is needed; planb-v12.sh calls it like a regular step.
- v12 expectations: `udev settle done` → `probe read OK` → `mountroot
  returned` → ext4 mount → Armbian systemd banner. If `rq start
  has no `rq done` → FTL read stuck for another reason (will inspect the blob).

## 35. Round 27 — v12 log breaks the FTL hypothesis: the 1-timer-4-CPU race is the real root cause; v13 = PERIODIC-only

- The v12 log holds two facts that betray the v11 hypothesis: (1) NOT a single
  `V12DIAG: rq start` line → no rknand read request yet, blkid/FTL
  innocent; (2) the marker `INITRD-DIAG: udev trigger done` does NOT print even though it sits
  right after the 2 trigger commands → hang in the `udevd --daemon` + trigger region, exactly
  when userspace forks furiously + CPU idle churn. (Packaging check:
  the marker IS in the flashed initrd.img.gz — not a pack error.)
- Timer inspection (v13-analysis1/2):
  - `timer-rockchip.c` (mainline 6.6): timer node 1 → clkevt; node 2 →
    clksrc+sched_clock. The log has only `clkevt registered` → the DTB has 1 node
    → clocksource = jiffies → `sched_clock: 32 bits at 100 Hz`. All
    system time depends solely on that one timer's tick.
  - clkevt: `cpumask=cpu_possible_mask`, ONESHOT feature → installed
    as the tick device of CPU0 AND as broadcast device for CPU1-3 (dummy
    local). `dummy_timer_register` in the log confirms dummy.
  - ONESHOT mode = re-program (disable→load→enable) EVERY tick + EVERY
    idle enter/exit. Broadcast re-program goes through `tick_broadcast_lock`,
    but CPU0's re-program (tick_sched/hrtimer) does NOT go through that lock →
    register race between 2 CPUs → lost arm → timer interrupts stop → completely
    silent hang. No softlockup/hung_task (those need a live tick).
  - ARM32 vDSO (CONFIG_VDSO=y): `cntvct_functional()` → CNTVCT dead →
    cntvct_ok=false → vDSO not mapped → every userspace clock_gettime goes
    through syscall → vDSO is no help (confirmed by reading vdso.c).
  - `rockchip_pd_keepon_release` lives in drivers/pmdomain/rockchip/
    pm-domains.c (late_initcall_sync) — not the culprit (there is no
    CPU pm-domain in our DTB).
- **v13** (boot.img only): (1) `v13-patch.py` on timer-rockchip.c:
  drop `CLOCK_EVT_FEAT_ONESHOT` (auto-reload PERIODIC, programmed once →
  no more race window, exactly like vendor 3.10), 5s heartbeat kthread printing
  `V13DIAG: hb jiffies delta ctrl cur load intst ce_state`, tripwire
  `V13DIAG: set_next_event` (must NEVER print); (2) config:
  `HZ_PERIODIC=y`, turn off NO_HZ + HIGH_RES_TIMERS (choice chain: use
  the exact symbol HZ_PERIODIC, NOT NO_HZ_PERIODIC); (3)
  `v13-initramfs.sh`: rewrite the entire init-top/udev script with a marker
  around each command + 15s watchdog (ps/uptime/interrupts/timer_list/
  wchan/stack) + 45s report + keep rule 59-rknand + probe mountroot.
- Lesson: the `find_one` of replace_next_after in v12-patch.py only
  replaces 1 line — features spanning 2 lines must be handled with a loop deleting the
  next line. Before flashing each vN: always grep the vN-1 log for the marker
  INSIDE the packed file (v13-check1.sh) to rule out packaging errors.
- v13 expectations: steady 5s heartbeat (ce_periodic=1), udev markers run to completion
  → probe read OK → ext4 → systemd. If watchdog prints → kernel alive +
  userspace stuck (inspect wchan). If heartbeat stops → tick dies elsewhere.
  `set_next_event` printed = wrong periodic assumption.
- v13 first build failure (user log): panic 0.000s right after "rk_timer
  clkevt registered" — `kthread_run` from `rk_clkevt_init`: TIMER_OF_
  DECLARE runs inside `time_init()` BEFORE `rest_init()` creates kthreadd →
  try_to_wake_up on a NULL task. Stack: do_raw_spin_lock ← try_to_
  wake_up ← __kthread_create_on_node ← kthread_create_on_node ←
  rk_timer_init ← timer_probe ← start_kernel. Fix: spawn heartbeat via
  `early_initcall(v13_hb_start)` + guard `IS_ERR_OR_NULL(rk_clkevt)`.
  Rule: in time_init/clocksource code a kthread may only be created when
  running at initcall or later.
- Docker Desktop died mid-session (npipe missing, container Exited
  137) → Start-Process "Docker Desktop.exe", wait for `docker info` OK,
  `docker start rk3128-build` — volume intact.
- v13 rebuild OK: PLANB_V13_DONE, boot.img md5 db78bbc86a210805fd08760
  a6465ccff (the earlier panicking build md5 6508eddc...).

## 36. Round 29 — v13 log: kernel alive up to trigger, dies SILENTLY after the final initcall chain; v14 = block keepon/clk + heartbeat via direct UART

- The v13 (fixed) log shows: `udevd daemon returned` + `trigger
  subsystems begin` printed OK → kernel + scheduler + fork/exec alive up to
  21.5s. BUT the 15s initramfs watchdog did NOT print → `sleep(15)` never
  completed → system timer/hrtimer dead within the 21.4–21.6s window.
  Conclusion: not a hang in udevadm — a whole-system dead state starting
  right AFTER the late_initcall_sync chain at 20.73s.
- Prime suspect (reading pm-domains.c): `rockchip_pd_keepon_do_release`
  (late_initcall_sync) clears GENPD_FLAG_ALWAYS_ON + queues
  `power_off_work` for every domain with `keepon_startup`. The rk3128 table:
  `DOMAIN_RK3288_PROTECT("vio",...)` → keepon=TRUE, and our DTB
  instantiates exactly `pd_vio` (`/syscon@100a0000/power-controller`,
  rk3128-pmu: pwr 0x04/status 0x08/req 0x0c/idle+ack 0x10). PD_MSCH
  is keepon=true too (pwr_mask=0 → req only). The PMU powers a domain off when idle
  conditions are met → absolute silent death (no panic — CPU/mem powered down).
  The rk3228 table (a different SoC) has PD_CORE keepon=true — not applicable to
  rk3128 but shows that their "keepon" is exactly the mechanism keeping domains alive at
  boot; releasing early is a risk.
- v14 (boot.img only): (1) `v14-patch.py` disables the keepon release +
  V14PDIAG on every domain power off/on + `clk_disable_unused` only LOGS
  ("V14CLK: would gate: <name>`) without gating + timer-rockchip.c: per-CPU irq
  counts, event counts every 5s, `V14DEAD` when the tick freezes (delta>6) or
  online collapse, and **heartbeat `V13HB:` written DIRECTLY to UART0
  0x20060000 (ioremap, bypassing printk)** — if the console driver is dead while
  the tick is still alive, we still see the pulse. (2) initramfs reuses v13.
- Technical lessons: (a) variable declarations must come BEFORE the IRQ function in the same
  file (the linker won't save you); (b) the anchor literal must match the blank line too
  (`event_handler(ce);\n\n\treturn`); (c) `rep1` assert x1 saved the build
  several times — keep that pattern; (d) `try_to_wake_up` panics at
  time_init because kthreadd doesn't exist yet (learned in v13, guard reused).
## 37. Round 30 — v14 log: KERNEL BOOTS ALL THE WAY THROUGH. Real culprit = clk_disable_unused gating sclk_timer0. Final blocker = ext4 data corruption on the rootfs

- v14 log: `trigger subsystems done → devices done → settle done →
  script exit` ran to completion for the FIRST TIME; V13HB heartbeat steady at 504
  jiffies/5.04s, irq incrementing only on CPU0 (+504/beat = nominal 100 Hz),
  ctrl=5, load=0x3a97f=239999 (24MHz/100Hz−1) ✓; all rknand rq res=0;
  probe read OK; fsck runs.
- **The real root cause of v10.1→v13**: the `V14CLK: would gate` list contains
  `sclk_timer0` (plus timer1-4) → enable_count=0 → the vendor-style timer
  driver (not going through timer_of) never calls clk_prepare_enable → the timer survives
  on reset defaults → at 20.7s `clk_disable_unused` gates sclk_timer0 →
  the tick dies silently → all sleep/hrtimer/udevd freeze. The SMP race
  hypothesis (v13) and the FTL race (v11/v12) were both wrong; the two "fixes" periodic-only and
  keepon were irrelevant but harmless.
- Minor bug in v14: forgot `v13_ticks++` → evts=0 meaningless (the irq counter
  is the real signal). `ps`/`ls` missing from the initramfs → watchdog output
  incomplete, "‑la: No such file or directory" — cosmetic.
- Final blocker (no longer boot-related): fsck -a wipes the journal itself
  (CLEARED) then hits `Inode 2741 invalid extent node (blk 204801, lblk
  0)` → status 4 → emergency shell `(initramfs)`. Origin: rootfs data
  from the moment of flashing or the FTL mapping — block-level reads return res=0, so
  there is no proof of who corrupted it. Way forward: fsck.ext4 -fy at the shell →
  exit → boot; if it breaks again → reflash the rootfs (consider rebuilding without
  a journal + fsck before shipping).
- v15 release plan (after booting to systemd): enable the clock timer
  THE PROPER WAY in rk_clkevt_init (of_clk_get + clk_prepare_enable),
  re-enable clk_disable_unused, keep the keepon release disabled (vendor-like),
  drop all V9–V14DIAG + heartbeat, drop rootdelay=60 (FTL reads proved
  fast), tune2fs -O has_journal if the journal should be restored.

## 38. Round 31 — the old fsck is far too broken → build a clean rootfs v15; the corrupt data lives on the NAND write path

- fsck -y on the box: hundreds of "Unattached inode ... Connect to
  /lost+found?" — corruption at scale → using it as-is = a garbage rootfs.
  e2fsck -fn on the workstation: BOTH the original A26 AND the shipped image are 100% clean →
  the corrupt data is born during the NAND write (FTL mapping/loader), not
  in the source files. Lesson: every large NAND flash needs a verify afterwards;
  this kind of corruption also explains the old "ReadRetry ecc=28" logs.
- `build-rootfs-v15.sh`: copy A26 → modules_install from the v14 build tree
  (an exact match for the zImage in boot.img) → /boot (zImage/System/
  config/DTB planb) → fstab drops the / entry (the initramfs mounts it; the wrong UUID
  was previously an emergency.target trap) → serial-getty@ttyS0 enable →
  tune2fs -O ^has_journal (FTL-safe; the stale journal is what killed
  the boot) → e2fsck -fy ship-clean → e2fsck -fn pass twice.
- Using `dumpe2fs -h`, `has_journal` shows ABSENT in the header when grepped —
  correct: the field disappears when the journal is off; check "Filesystem state:
  clean" + tune2fs -l | grep -i journal instead.
- Rootfs v15: output/armbian_rootfs_v15_xmio.img sha256 c09cbd03...;
  flash only 0x17000 (v14 boot.img unchanged). Expectation after reflash:
  clean/fast fsck → systemd → UART0 login.
- RKDevTool fails immediately with v15 (loader OK, % never runs) while the old
  file flashes fine → ruled out one by one: the v15 file is intact on the host
  (hash OK); the OLD FILE is exclusively LOCKED (host Get-FileHash fails, docker
  Permission denied — RKDevTool holds the handle) → byte-diff must wait for the user
  to close the tool. Known old-vs-v15 differences: has_journal cleared, modules
  built from v14, fstab UUID dropped, serial-getty@ttyS0, fresh /boot.
- Spare ammo: `C:\Temp\v15b.img` (a Windows-native copy of v15,
  hash c09cbd03... identical) and `armbian_rootfs_v15j_xmio.img`
  (v15 + tune2fs -O has_journal -J size=16→default, e2fsck -fy clean,
  273633/282604 blocks, sha256 5457bc19...). Decision tree: v15b →
  v15j → v15j@C:\Temp → plan B dd-on-box (UART shell + USB stick
  FAT32: mount vfat, dd bs=4M, e2fsck -fn verify on the spot, reboot).
- Docker Desktop fell over a second time in the session (host restart?) — same
  recovery: Start-Process + wait for docker info + docker start the container.

## 39. Round 32 — Box BOOTS INTO ARMBIAN (shell login OK). v15 release: strip all diag, clean cmdline

- Milestone: user flashes the rootfs (RKDevTool finally OK with v15/v15b after
  resolving the file-lock conflict) → boots to the Armbian login shell
  on UART0. Complete Plan B chain: stock U-Boot 2014.10 → boot.img
  (zImage 6.6.89 + initramfs A26) → rknand FTL → ext4 rootfs (no
  journal) → systemd.
- The question of "turning off kernel logs": 2 sources that cannot be disabled at runtime —
  `ignore_loglevel` in the cmdline (disables dmesg -n) and the V13HB direct-
  UART (bypasses printk). A fresh kernel build is the clean path.
- `v15-release.py`: remove heartbeat kthread + V13HB emitter + v14
  counters + tripwire + V12DIAG rq/gc prints + V14CLK/V14PDIAG; KEEP
  PERIODIC tick, clk gating off, keepon off-release, GC off, V9/V11
  boot one-shot prints. `planb-v15.sh` sed parameter.txt: remove
  initcall_debug + ignore_loglevel + rootdelay=60 (boot 60s faster,
  normal console loglevel, dmesg -n works from now on).
- Verify: 8/8 diag strings GONE, 2 boot one-shots KEPT; boot.img md5
  7658e3b20a27b7b6ead03eace6e8b187; parameter.txt sha256 ab7c5744...
  (backup parameter.txt.v14diag.bak keeps the old cmdline). Flash 2 files:
  parameter→0x0 + boot→0xE000.
- Remaining work for "official": consider enabling sclk_timer0 properly
  (of_clk_get + clk_prepare_enable) so that clk_disable_unused can
  be re-enabled — but with gating currently off, not urgent; HDMI/USB/eth iteration
  next; acceptance.sh update (optional).

## 40. Round 33 — Fixed ethernet MAC via DTB local-mac-address (v15.1)

- Symptom: v15 release boots OK, eth probe OK (DWMAC1000, RMII,
  clock output), but `rk_vendor_read eth mac failed (-1)` → random
  MAC every boot (`d6:61:11:b4:96:04`), `rk_vendor_write` also fails.
- Root cause: vendor storage init failed inside the FTL (IDB region — old log
  `rknand vendor storage init failed !` + `ReadRetry ecc=28`); fixing
  this region at the root = a rabbit hole, not worth it vs. the DTB fix.
- MAC resolution chain in stmmac 6.6: `stmmac_probe_config_dt` →
  `of_get_mac_address` (DT `local-mac-address`/`mac-address`) →
  `stmmac_dvr_probe`: `if (!is_zero_ether_addr(res->mac))
  eth_hw_addr_set(...)` runs BEFORE `stmmac_check_ether_addr`
  (only runs when the addr is invalid: uMAC regs → get_eth_addr hook → random).
  ⇒ a valid DTB mac = the vendor hook is bypassed entirely.
- `planb-v15.1.sh`: v8 DTS + `local-mac-address = [02 31 28 16 01 28]`
  → `xmio-planb-v9.dts` → dtc → pack_resource.py (RSCE 1 entry
  rk-kernel.dtb) → mkbootimg. resource.img md5 00c0cf8ed4545044d9aa
  4d368b2fa89e @0x6800; boot.img md5 0b7243bebebaa1adb66c1e5bff7356bc
  @0xE000 (the second blob must be in sync with resource).
- DTS chain now: xmio-planb.dts(v3) → v4 → v6 → v8 → v9 → v16. The original MAC can
  be recovered if the user checks the router's DHCP lease history / the box's shell label
  (the vendor area was already unreadable before, possibly wiped during flash erase).

## 41. Round 34 — v16: SD enabled, background FTL GC restored, codec disabled

- User reported 4 groups of red errors + symptoms: SD not detected, internal IO very
  slow with FtlWrite, HDMI not detected, etc. Diagnosis:
  1) `mmc2: Failed non-removable` = wifi SDIO @10218000 (no wifi
     firmware) — harmless; **the real TF slot is mmc@10214000, currently
     `status="disabled"` in the DTB** (every previous planb version!). Stock
      uses `broken-cd` + cd-gpios; we chose broken-cd polling.
  2) `FtlWrite: lpa error:ffffffff` + ReadRetry ecc=28 err=ffffffff
     repeating at pages 0x10706e–77 = hot FTL mapping pages; the cause:
     background GC off since v12 (falsely blamed; the real freeze was the tick timer — v14).
     v16 restores gc_do=1 (2 sites, as vendor) + the v16_ftl_ready flag
     opens the gate after rk_ftl_vendor_storage_init() returns → blocks the
     v11 race window (GC spawned before vendor init; broken IDB makes init take
     8–12s). Idempotent marker V16GC_READY.
  3) i2c-4 modalias failure on /hdmi@20034000/ports: harmless (inno
     hdmi creates its own I2C DDC adapter; of_i2c tries to instantiate the ports node).
  4) sip_smc_get_dram_map error: no ATF, harmless, cannot be fixed.
  5) mpp_rkvdec/rk_iommu red: the vendor codec drivers need vendor clock/reset
     outside the mainline DT → disable 6 nodes (hevc/vepu/vdpu/iep/2 iommu).
- HDMI: inno_hdmi.c HAS rk3128 (rk3128_hdmi_phy_config + drv_data);
  node okay + VOP bound + route okay — need the `dmesg|grep -iE` log
  'hdmi|vop|drm'` + `/sys/class/drm/` from the user for the next round.
- Build: 3 fix rounds (missing cd $SRC; non-idempotent patcher stuck from the first
  build; verify dts index caught an alias). Final OK: boot.img
  md5 6290e7ced46cbb0a4750f0c493c6055e @0xE000; resource.img
  md5 2fdf4544d6441fa45e73a24fe50cae09 @0x6800.
- Waiting for user tests: SD detect/read/write; whether slow IO + FtlWrite remain
  (GC needs a few minutes to recycle blocks; ECC-error pages may still repeat
  but the FTL will remap them); then the HDMI log.

## 42. Round 35 — SD OK. v16.1: force-enable HDMI via cmdline

- User confirms: SD detected OK. IO slightly slow (deferred). HDMI: driver BIND
  OK (`registered Inno HDMI I2C bus driver`, `bound 20034000.hdmi`),
  connector card0-HDMI-A-1 exists, drm minor 0 OK, lima GPU minor 1.
  But `Cannot find any crtc or sizes` @2.95s = no display detected
  at boot (HPD/EDID returns empty).
- Cheap first step: cmdline `video=HDMI-A-1:1920x1080@60e` (force enable
  regardless of HPD/EDID) — flash only parameter.txt @0x0 (md5
  bdbc762dd4bbcaab058fb630440c389c, backup parameter.txt.v16.bak).
  Expectation: image appears = phy/encoder OK, only the HPD/EDID bug remains (IRQ/DDC);
  no image = a deeper fault (phy config/clk), will need status/modes/
  edid/interrupts logs. Plan B if 1080p won't lock: 720p60.
- Still in the queue: slow IO/FTL remap monitoring; `failed to parse
  loader memory` + `drm-logo@0 failed to reserve` (harmless — the
  uboot logo isn't in the planb chain); disabling codecs in v16 is intentional.

## 43. Round 36 — HDMI OK (force mode). Slow IO investigation

- User: HDMI works (not smooth yet), SD OK, IO "still a bit slow": iostat
  rknand_root 304 kB/s read, 22% iowait (average since boot).
- Driver discovery: the RK nand driver has a `bad_nand=` cmdline param
  (rknand_bad_nand_level) that lowers NANDC clk 150→50/25MHz + increases FTL reserved
  space; default = 0 (not degraded) — the current cmdline doesn't have it.
  `rknand_probe clk rate = %d` will confirm the actual clock.
- Diagnostic weapon: `/proc/rknand` — internal FTL dump (blob
  rknand_proc_ftlread, 64KB) + counters (ftl_read/write_error_count,
  total_*). Waiting for the user benchmark: dd raw /dev/rknand_root + file
  test + /proc/rknand before/after + counting ReadRetry during the test.
- Two scenarios: raw ≥3-5MB/s → FS/sync overhead, tune readahead;
  raw ~300kB/s → structural: check the clk rate; if 150MHz is correct yet slow
  → ReadRetry storm in the LUT region → the standard RK remedy: erase the whole NAND +
  clean reflash so the FTL rebuilds (fresh LUT/bad-block table).

## 44. Round 37 — v17 timer OK (µs timestamps). IO: NAND worn out

- v17 timer2 @0x20044020 works: user dmesg stamp [6.327107] has
  microseconds — no more 10ms quantization. Clocksource/sched_clock alive.
- IO results on v17: raw read 256MB = **776 kB/s** (21ms/16KB,
  ~200x slow), file read 780 kB/s, write 64MB buffered 0.6s (cache;
  real through sync). /proc/rknand: ftl_read/write_error=0 (v16 GC fix
  ✅), free_superblocks=489 >> th 60 (GC healthy ✅), clk 148.5MHz
  (not degraded ✅).
- FTL dump = hardware diagnosis: totle_write 859,711 MB lifetime
  on a 4GB die (~215 full-die cycles), totle_read 530,815 MB (read
  disturb), bad blk 20+35=55, min_EC/max_EC 11,258/12,012 (MLC spec
  ~3k), Read Err 1,314, GSV/GDV + 16 GC sb listed, mlc_EC total
  0x333102b2. Conclusion: the MLC cells are worn out, every page read must retry
  sweep — there is NO software fix to recover.
- Result for the user (bad_nand=1 + zone survey): clk 50MHz OK but
  256MB read = 767 kB/s (≈776 unchanged); skip=0 397MB/s (cache hit
  — the experiment lacked drop_caches); skip=3840 = 0 bytes (end of device
  — MaxSector 0x750000 = 3,745MB < 3840MB). Key point: 50MHz ==
  148.5MHz in speed → the bottleneck is NOT cell bandwidth/timing
  but a FIXED COST/page independent of the clock.
- Do the math: 16KB / 767 kB/s = 20.9ms ≈ HZ/50 timeout hack; chased
  it: the ftlv5 blob does NOT call rk_nandc_irq_init (ftl_arm_v7/zftl does
  call it) → suspected IRQ timeout — BUT nm -u on the blob: waits via usleep_range,
  NOT the timer-hack path. All 4 call sites sleep 1–5 µs (poll
  loop ~2 times/page). Our kernel HZ=100 + NO CONFIG_HIGH_RES_
  TIMERS (selectively chosen v13) → each usleep_range = a full 10ms tick →
  2 ticks = 20ms/page → 767-796 kB/s. PERFECT MATH MATCH. Since
  it is time-based it does not change with clk — bad_nand has no effect on speed.
- Fix v17.2: 4 sites `bl usleep_range` → `bl rk_ftl_udelay` (new C
  helper: udelay busy-wait, independent of timer/HRT/IRQ; the blob already uses
  arm_delay_ops elsewhere, so this is this SoC's vendor idiom).
  Verify: 0 usleep_range in object; rk_ftl_udelay links OK (c0a804ac).
  boot.img md5 5a9a44c6049c8fa429f5770d34f23f4d @0xE000, resource
  c1901e0b2fb6e9a80052647b4899be0e @0x6800 (same as v17).
- Expectation: throughput jumps to a few MB/s (the real limit of the worn die).
  Note: the old 767 kB/s had 20ms/page of WAITING, not slow worn cells;
  the EC 11.5k figure is still real but contributes little to this bottleneck.

## 46. Round 38 — v17.2 CONFIRMED ON HARDWARE: 10× speed, 30s boot

- User measured after flashing v17.2: raw read 256MB = **7.5 MB/s** (from
  767 kB/s — 10× faster), skip=768 zone = 8.1 MB/s (uniform across zones),
  **boot 2 minutes → 30 seconds**. Feedback: "oh, much better now".
- IO chain summary: the bottleneck was NOT worn cells (EC 11.5k is still
  real but just background) but usleep_range(1–5µs) → 10ms/tick on
  a kernel without HRT → 2 ticks/page. Fix: 4 asm instructions + 1 C helper.
- Final subsystem status (all user-confirmed on the
  hardware): boot ✅, eth/MAC ✅, SD ✅, HDMI ✅ (force mode, user accepts
  it), FTL GC/FtlWrite ✅ (error 0), IO ✅ 7.5 MB/s, boot 30s ✅.
- Leftovers (not blocking the goal): wifi SDIO not brought up (not
  in the original requirements), HDMI "not settled" per the user (force mode
  instead of HPD/EDID), vendor storage permanently dead (IDB broken — sidestepped
  via DTB MAC), bad_nand=1 optional keep or drop (same speed).
- GOAL COMPLETE: flashable image + complete FLASH-GUIDE (parameter/
  uboot/misc/baseparamer/resource/boot/rootfs + sections Z.1–Z.4).

## 47. Round 39 — goal complete. Next from the user: HDMI "more proper" (1) + write measurement (2)

- User confirms v17.2: 7.5 MB/s read (×10), 768MB zone 8.1 MB/s,
  boot 30s. Goal goal-254ad246 marked complete (rev 5). User asks
  next: (1) HDMI more standards-compliant, (2) measure write speed.
- HDMI analysis (v18-analysis1..4): hdmi planb node = YES all of
  mainline rk3128.dtsi (SPI45 LEVEL_HIGH, aclk/pclk, grf, pinctrl
  hdmii2c_xfer/hdmi_hpd/hdmi_cec, ports graph complete) — DT is NOT missing.
  Driver: connector.polled = HPD only; detect() reads the m_HOTPLUG bit
  in HDMI_STATUS; HPD IRQ (threaded, IRQF_SHARED) unmuted before
  request. If the IRQ never fires (or the cable is plugged in after init) → never
  re-detects → no EDID.
- v18 patch (tools/v18-hdmi-poll.py, marker V18HPD): polled |=
  CONNECT|DISCONNECT → DRM delayed work polls every 10s calling detect()
  regardless of IRQ. If the HPD bit reads correctly → EDID captured on the first poll → can drop
  force mode from cmdline after verification. boot.img
  e7f76c4ac37e41eaf3d01585d108ba76 @0xE000 (resource keeps c1901...).
- Diagnostic set handed to the user: status/modes/edid/interrupts before + after
  plugging/unplugging the cable. Three branches: connected+modes+edid → drop force mode;
  disconnected → HPD bit dead, dig into GRF/pins further; connected+edid
  empty → DDC/i2c fault (pclk/tmds rate).
- Write measurement: no command for the user in this reply yet (waiting for the HDMI
  output first); instructions: dd conv=fsync + /proc/rknand comparison.

## 48. Round 40 — v18 verified: HDMI fully alive. v18.1 native. Write 4.5MB/s

- fsck incident at round start: boot hit orphan inode 337 (old damage
  from the hard-reset era), fsck.ext4 -y at the initramfs prompt fixed it,
  user rebooted normally. udelay loop budget verify: r4=100000
  × ~1.5µs ≈ 150–250ms vs vendor-healthy 200–400ms — patch preserves
  vendor semantics, no time bomb.
- HDMI diagnostics by the user (v18): HPD IRQ GIC-0 77 counts 2→269 on plug/
  unplug; status toggles correctly; EDID 128B+ valid (TV id 4d 67 a8 27, preferred
  1080p60 @148.5MHz, 70+ modes). All three layers (IRQ/HPD/DDC-EDID) alive.
  Root cause of the black-screen boot: TV handshake 2.9s slower than kernel init +
  no re-detect — the v18 poll self-heals.
- v18.1: parameter.txt.native md5 8a1c78811d2c83b783115d426612bb02
  (video= force removed) — user flashes @0x0, expect console ~10s after
  boot via poll; fallback = parameter.txt force-mode.
- Write: 64MB + 16MB conv=fsync both 4.5 MB/s, ftl_write_error 0.
  Read 7.5–8.1 MB/s. Box reaches production-usable level.
- Open question for the user: what exactly is the HDMI "not settled" (overscan/
  delay/frames) — if it is TV overscan, adjust margins via video=;
  if nothing else, HDMI is complete in native mode.

## 49. Round 41 — HDMI settled OK. Journal enabled in 2 tiers

- User: HDMI fine (not used much) — settled on native mode, no more digging.
- User asks to enable the journal on the rootfs. Discovery: the workspace already
  has `armbian_rootfs_v15j_xmio.img` (has_journal 32M, created in the Round v15
  era) — e2fsck -fn PASS (37376 files, 273633/282604 blocks, 0.1%
  non-contig), journal seq 0x1 start 0 (fresh), sha256
  5457bc19e70a67762671fa1edbc8b7739d0d65dcc834aa11f71de7d3439337f7,
  md5 f84615bd7879df1562dcef58571059e7, 1,157,545,984 bytes =
  2,260,832 sectors — matches the rootfs window @0x17000.
- Two tiers to enable the journal: (1) on-box tune2fs -O has_journal -J size=32
  /dev/rknand_root (online; if e2fsprogs refuses on the mounted fs →
  tier 2); (2) flash v15j @0x17000 (overwrites the rootfs — loses edits
  made since the v15 flash; back to a clean image + journal).
- FLASH-GUIDE Z.7 written. Note: fstab has no noload/nojournal →
  journal replay works automatically at mount. data=ordered default.

## 50. Round 42 — v18.2: IO accounting for iotop (user reports idle-IO)

- iostat user: read 153 kB/s / write 113 kB/s avg-since-boot, iowait
  0.78% (very low). iotop does not run — kernel lacks CONFIG_TASKSTATS
  (TASK_DELAY_ACCT/XACCT/IO_ACCOUNTING dependencies do not exist).
- v18.2: add the 4 accounting configs (=y), olddefconfig, rebuild zImage;
  verify 4 opts + taskstats symbol; boot.img md5
  67960509190f9f31583b7cb4e2a2e1eb @0xE000, resource c1901...
  (same as v17/v18).
- Explaining the numbers to the user: first iostat block = since-boot; 172MB read
  ≈ full-FS fsck (fsck.ext4 -y ran at the Round 39 initramfs), 127MB
  write ≈ fsck repairs + journal enable + log. LIVE rate must be read via
  `iostat 5 3` (samples 2-3). task_delayacct default off since 5.13 →
  sysctl -w kernel.task_delayacct=1 when iotop is needed, turn it off again afterwards.
- Not yet answered the user about the specific background IO cause (waiting for
  iotop/pidstat output after v18.2). Suspects: journald/syslog periodic, NTP
  drift file, apt-daily timer. FTL internal GC does NOT show up in block
  stats (does not go through the block layer).

## 51. Round 43 — Status LED request (red/green 2-color + yellow IO)

- No LED node in either the stock DTB or planb (XMIO drives its GPIOs
  outside the DT). Kernel already has: LEDS_GPIO=y, TRIGGERS=y, TIMER/ONESHOT/
  DEFAULT_ON=y; GPIO_SYSFS=y (probeable right away).
- v19 kernel: added LEDS_TRIGGER_HEARTBEAT=y (red blink during boot).
  LEDS_TRIGGER_DISK was dropped by olddefconfig due to `depends on ATA` (no
  libata / don't want it); LEDS_TRIGGER_BLKDEV doesn't exist in this tree
  6.6.89 → yellow LED = userspace poller on /proc/diskstats (delta
  sectors → blink), no extra kernel needed.
- boot.img v19 md5 89a141490847e26dac39f194daec2172 @0xE000 (already
  built, NOT flashed yet — waiting for pin discovery to combine in one flash with DTB
  v19.1).
- Candidate GPIO list: 46 pins not claimed by pinctrl (gpio0: 4 5
  10 16 18 19 21 22 23 29 31; gpio1: 38 45 55; gpio2: 92 94 95;
  gpio3: 96..127). Probe script given to the user to run on the CURRENT
  system (sysfs toggle 4 times/pin, ~2.5 minutes), user reports pin↔LED.
- Overall design: DT leds node (red default-trigger=heartbeat, green
  off, yellow off) + systemd service xmio-led (loop 0.5s: net up →
  green, else red; yellow follows the diskstats delta). Boot hang → red
  heartbeat keeps blinking = a natural "booting" indicator.

## 52. Round 44 — v19.1 LED packaging complete. Real pins: gpio0_B0 + gpio1_B1

- Probe round 2 still failed due to wrong absolute coordinates (guessed base); round 3
  (debugfs base + fractional sleep check + per-pin log) → user reports:
  pin 8 = red+green (gpio0_B0, anti-parallel), pin 41 = yellow (gpio1_B1).
- pinctrl analysis (v19-analysis7.py): 69 groups, only 30 pins belong to
  active devices (sdmmc/sdio/uart0/rmii/pwm0-2/otg-vbus); i2c PMIC pins
  actively excluded. 96 safe pins — probe list is correct.
- DTB v19.1: xmio-leds node, dual rg default-state=on heartbeat
  (pin low = green always on plus red blink — 1-pin LED constraint),
  yellow default-state=off. Verify: pin cells 0x8/0x9 (dtc prints hex
  as 2-digit — 2 regex failures before matching), 2 different phandles,
  correct chips gpio0/gpio1. dtb md5 7b25cb3d8facaf95f601d6a9e11acafc.
- boot.img d9b7bb3bb16d4cff47bb73dffe369825 @0xE000 (kernel v19 +
  DTB v19.1 in resource), resource.img a032aeaf8c1e1d83f1e927196d7c21d0
  @0x6800. Flash BOTH.
- onbox/: xmio-led (sh poller) + xmio-led.service. Swap colors if reversed:
  change the 2 brightness lines in the service. Kernel v18.2 (iotop) not
  flashed yet — v19 already includes TASKSTATS (incremental config build).

## 53. Round 45 — v19.2: yellow ACTIVE_LOW, instant service

- Real hardware: yellow lit inverted → the yellow LED is active-low, fixed at the DTB level
  (io-led flag 0x01), service logic kept. boot.img
  c8d5e478a813a45e75f55f469f2cc122, resource
  08f99cd17bd8bb76937a0adbea868169. zImage unchanged (v19).
- Slow red/green: cause was the unit's `Wants=network-online.target` —
  the service waited for DHCP. Removed; detection switched to carrier + operstate, loop 0.3s.
- User flashes + reinstalls the service. No feedback yet; if red/green are still
  inverted after v19.2 → swap the 2 brightness lines in the service.

## 54. Round 46 — v19.3: green LED = REAL connectivity (IP + gateway)

- User correctly pointed out: the old script treated carrier=1 as "network up". v19.3
  semantics: GREEN = global IPv4 (scope global, excludes 169.254.x.x —
  grep scope global already filters out APIPA) + ping gateway -W1; RED = no
  carrier / no IP / DHCP fail / gateway silent. Full-check ping
  every 10 ticks (~3s) when carrier is up, carrier check every 0.3s tick
  (unplug → instant red). No gateway route but has a global IP →
  still green (LAN-only). No ping binary → trust the global IP. No ip
  → fallback to /proc/net/route default entry.
- ONLY the onbox/xmio-led file changes — do NOT flash kernel/DTB. User
  re-pastes the script + restarts the service.

## 55. Round 47 — v19.4: green-light root cause = lo carrier=1 + basename

- end0 NO-CARRIER state DOWN yet LED green. Cause: skipping lo via
  `basename` + comparison — unreliable on the box → loopback carrier=1
  counted as link → NET=1 forever → green forever. Red boot before systemd
  = DT default-state=on (pin high = red) — confirms polarity 1=red.
- Heartbeat doesn't blink pre-systemd: retro-bind exists (led_trigger_
  register line 309 of led-triggers.c) but binds after probe; the service writes
  none + brightness overrides it. Drop the DT-trigger machinery for the boot phase: the service
  ITSELF blinks red when "link up but not yet decided" (DHCP window),
  once decided → holds a steady color. Pre-systemd = solid red (accepted).
- v19.4: case-filter */lo|*/sit0 (no basename), trigger none set ONCE
  at the top of the script (avoid fighting), blink 0.5s when NETOK="", net_full
  every 10 ticks when link is up, unplug → instant red. Service ONLY — no
  flashing. User needs to confirm yellow is correct after the v19.2 flash.

## 56. Round 48 — v19.3-DTB: drop heartbeat. "Steady green" = a blink cadence

- User on v19.4: boot with no network still green; manual service restart → red.
  Decoding: dual LED on 1 pin — heartbeat pin-LOW phase ~1.5s (green lit)
  vs pin-HIGH 140ms (red flash) → looks like "steady green". Probe race:
  some boots the trigger binds (fake green), some boots it doesn't (solid red). When
  the trigger is active, the service's brightness writes get swallowed by the kernel into
  blink_brightness → the service can't win the LED back → green until the manual
  restart (echo none is the only way to clear the trigger).
- Fix at the DTB level: remove `linux,default-trigger = "heartbeat"` from
  status-led (v19.3-dts.py on top of the v19.2 chain). Pre-systemd = solid red
  (default-state on, deterministic). boot.img
  e1049ce3192fbe40d5d19d9a4e435564, resource
  f8f65d1afc7846a56ff4b0c6a4e47926. zImage stays v19.
- onbox/xmio-led adds a log /tmp/xmio-led.log (md5 a1f6b38256be3b75ad3ca560d840865a,
  86 lines) — re-paste only if evidence is needed. The v19.4 script on the box has
  run correctly (manual restart → red).

## 57. Round 49 — Real root cause: armbian-led-state restores the old trigger

- User suggested armbian-led-state.service. Dissected the rootfs (debugfs, no
  mount): unit WantedBy=basic.target, ExecStart=restore.sh (restores
  brightness+trigger SAVED AT SHUTDOWN), ExecStop=save.sh. The "ghost
  green" mechanism: one boot heartbeat bind → shutdown saves trigger=heartbeat → every
  later boot restores it → pin low 1.5s/cycle = "steady green" + brightness
  writes of the service get swallowed. Combined with the suspicion that xmio-led was NOT enabled
  (the later pastes only restart it) → nobody clears the trigger at boot.
- v19.5: do NOT reuse armbian-led-state (crude save/restore, clings to stale
  state); disable it. The xmio-led service moves to WantedBy=basic.target
  (runs early), blinks RED throughout boot until multi-user + net decided
  (matching the original spec "kernel boot → blink red"), then holds a steady color. is-active
  multi-user cached every 4 ticks. md5: script b38bffef1a2d8cf570729b636878585c,
  unit 69777ba31a85822d496516dffa640048. Conflicts=shutdown.target.
- Pre-systemd (kernel/initramfs): solid red from default-state=on (DTB
  v19.3 already dropped default-trigger). Flash the v19.3-DTB if not done yet.

## 58. Round 50 — v19.5 OK on the box. Why disable armbian-led-state

- User confirms the LED behaves correctly ("it's fine now"). Asks why disable
  armbian-led-state instead of putting it to use?
- Read save.sh/restore.sh from the image (debugfs): a oneshot save-at-shutdown
  (trigger + params → /etc/armbian-leds.conf) / restore-at-boot
  (basic.target replay). No network/IO logic.
- 3 reasons to disable: (1) it is itself what spreads the "ghost green" — the conf stores
  a stale trigger=heartbeat and restores it at every boot; (2) redundant — the xmio-led
  daemon enforces 0.5s from basic.target, so the restore is overwritten right away; (3)
  single-owner principle. The only value it could add: keeping the last
  color across a reboot (conflicts with the boot=blink spec).
- Safe re-enable if wanted: rm /etc/armbian-leds.conf + enable;
  our unit already has After=armbian-led-state.service (no race). The
  decision is left to the user; default stays disabled.

## 59. Round 51 — v19.6: zero-fork steady state (CPU 1-3% → ~0.1%)

- User measures xmio-led at 1-3% CPU — abnormally high. Root cause: the shell
  script forks 10-15 processes/second (cat ×2, awk, subshell, sleep, occasionally
  ip/grep/ping/systemctl). Each fork+exec ~1-2ms on the A7.
- v19.6 zero-fork: read builtin replaces cat (carrier/operstate/diskstats/
  uptime), systemctl is-active only until BOOT is set (after that
  never), net_full every 20 ticks (10s, 3 forks), log every 600 ticks
  (5 minutes). Steady: ~0-1 fork/tick = 2 forks/s (the sleep builtin is
  the only remaining /bin/sleep fork each tick... shell sleep builtin
  busybox? dash has no builtin sleep → still 1 fork/tick but cheap).
  md5 7270cbba1e5db0952e2b897cc9cf5160.
- Expected re-measurement: <0.3%. If the user wants 0%: kernel-space (custom LED
  trigger) — overkill, not proposing it unless the user asks again.

## 60. Round 52 — v20.0: C daemon replaces the shell (CPU 2% → ~0%)

- v19.6 is still 2% — the `sleep` fork + shell loop on the A7 is still too expensive, and
  cannot be optimized any further in shell. Recall: the ledtrig_disk_activity
  hook only exists in libata (SATA) — rknand does not go through it → the yellow LED
  cannot be done with a kernel trigger.
- tools/xmio-led.c (v20.0): zero-fork daemon. 400ms tick via nanosleep;
  getifaddrs (IFF_RUNNING + global IPv4, excluding lo/sit/tun/virbr);
  gateway from /proc/net/route; ping = self-written SOCK_RAW/DGRAM ICMP
  (no fork, only every 20s while the link is up, poll timeout 1s);
  multi-user = access invocation:multi-user.target + fallback uptime
  90s; diskstats fscanf every tick; writes sysfs ONLY when the value changes
  (reduces kernel workqueue churn). Env overrides XLED_STATUS/YELLOW/
  TRIG for testing. arm-none-linux-gnueabihf-gcc -Os → 9.7KB dynamic
  armhf (glibc older than the box's → forward compatible ✓).
- Smoke test under qemu-arm-static: daemon runs, blinks exactly 1,0,1,0 @400ms,
  yellow 0, exits when the LED file is missing (correct logic).
- Deploy package: onbox/xmio-led-c.b64 (gzip+b64 5.2KB, 68 lines,
  gz md5 daae99399b23db9a78472fa2f99ab0ca). User pastes → base64 -d |
  gunzip > /usr/local/bin/xmio-led-c → md5 verify → unit ExecStart
  switched to the binary → restart. The shell script is kept as a fallback in the
  workspace.

## 61. Round 53 — UART paste broke a second time. Rule: NEVER transfer binaries

- The 68-line b64 paste from chat → "invalid input" + broken gz (md5
  mismatch). Cause: I typed the base64 by hand into the message + the UART dropped
  characters. NEW RULE: binaries/long blobs NEVER go through a hand-typed
  channel (chat) — only via (a) LAN scp/wget from a real file on the PC
  (the bind mount makes the file show up ready on the Windows side), or (b) copy from a FILE
  on the PC (Notepad) with per-chunk md5.
- Prepared: onbox/xmio-led-arm.gz (Windows-side md5 matches ✓),
  chunkaa..chunkad (17 lines/chunk) + cumulative md5 table 11e6411f/
  ac9fecd0/c7344f2b/0e96391d. Final check of the binary:
  05874d5e606790ab2fef2f5ca4b58e9e.

## 62. Round 54 — v20.1: gateway byte-order fix, ping hits the wrong public IP

- User: "the C build blinks for a long time then goes red; still the same with the network cable unplugged". Root cause:
  /proc/net/route prints the gateway as a u32 in host order on the LE box
  (192.168.1.1 → 0101A8C0; test container: 172.17.0.1 → 010011AC).
  v20.0 additionally applied htonl() → pings 1.0.17.172 (byte-swapped!) → timeout →
  permanently red. The old shell version was unaffected because it used `ip route` (prints dotted).
- v20.1: build the IP bytes by hand in LE (b[i]=g>>(8i)); + dlog
  /tmp/xmio-led.log transitions-only (uptime, link up/down, ping
  gw=x.x.x.x -> reply/timeout, netok change, status RED/GREEN);
  set_status/set_yellow write sysfs only when the value changes.
- qemu verify: hex=010011AC parsed=172.17.0.1 → ping reply → netok=1
  → blink → boot=1 → GREEN. Matches the spec sequence.
- Deliverables: xmio-led-arm.gz md5 5ae567b47a2e01158bf9712b3e1df339
  (4322B); binary 09061b862d8cd47cae3d320e3f81f3a9 (9796B); b64 77
  lines → 5 chunks, cumulative md5: 0bfbd6d0/4fc04c5f/5bc7dc05/
  9fb7c9d8/384bf803. Install: replace the /usr/local/bin/xmio-led-c file
  (unit keeps ExecStart=xmio-led-c) + restart; verify via the log.

## 63. Round 55 — v20.2: boot-detect fix; user considers stock mode

- User's log proves it: gateway fix OK (ping 192.168.100.1 reply,
  netok=1) BUT it blinks forever — "boot=1" never arrives. Root
  cause: /run/systemd/units/invocation:multi-user.target is a DANGLING
  symlink → access() follows it → always ENOENT → waits for the 90s fallback.
- v20.2: lstat() replaces access() (does not follow symlinks) + re-probe
  every 2s while there is no IP yet (next_probe logic, replacing tick%PING_EVERY).
  qemu: blink → boot=1 @~1.6s → GREEN ✓.
- Deliverables: gz ee18c866a2dc6df8e962f4e39d3df4c1 (4064B), binary
  ee3fa38a5e624991a494cd84661a90c8, b64 5 chunks cum md5 9d40c310/
  06e2e53e/cfb36469/2e3a7678/d3bccf1d.
- User says "go back to armbian-led-state, accept the limitations" + sends a link to
  the DT binding common.yaml. Analysis done: armbian-led-state is only
  save/restore — it produces no behavior by itself; stock mode = heartbeat
  (blinks GREEN on the inverted-polarity wire, not red), netdev is carrier-only,
  no IO for rknand. Presented a comparison table + suggested trying v20.2 first;
  only once "do stock mode" is settled would we build v19.4-stock (heartbeat DTS + enable
  service). Not built yet — waiting for the user's final call.

## 64. Round 56 — user settles on "do stock mode". Build v21/v19.4-stock

- Kernel triggers available (v19 .config): timer/oneshot/heartbeat/
  default-on; NETDEV missing → rebuild. LEDS_TRIGGER_DISK dead
  (ATA), BLKDEV does not exist in 6.6.89 → yellow cannot be done
  with a trigger; accept leaving it off.
- DESIGN DISCOVERY: flipping the status-led flag to ACTIVE_LOW (0x01) makes
  every trigger favorable: "on"=GREEN, "off"=RED. heartbeat at boot =
  predominantly RED blinking (not green as the old warning said — that warning
  was based on the old polarity). DTB v19.4: gpios <ph 8 0x01> +
  default-trigger=heartbeat + default-state=off (pre-trigger RED).
- netdev trigger 6.6.89: attrs device_name/link/link_10..1000/
  duplex/rx/tx/interval; does not read DT (needs userspace to set device
  name ONCE); notify rebinds when the iface registers; save.sh writes
  trigger= first then params → restores in the right order; brightness is NOT
  stripped (a trigger named "netdev" ≠ *":link") but restore skips
  brightness=0 ✓.
- planb-v21.sh: -e LEDS_TRIGGER_NETDEV + olddefconfig + zImage +
  v19.4-dts.py (from v19.3.dts) + verify (MAC/sdmmc/timer/dual 0x01/
  yellow 0x01/heartbeat present/state off) + repack + layout OK.
  boot.img 6d405bf6f5ece040bd470a62f19ff2d6 @0xE000; resource.img
  aff898ad7913fc76ea5afe9fc10c6ec0 @0x6800. FLASH-GUIDE Z.11.
- On-box stock setup: disable --now xmio-led; rm old conf; enable
  armbian-led-state; once: echo netdev > trigger; end0 >
  device_name; 1 > link; 0 > rx/tx. Behavior: boot flashes red →
  GREEN (wired) / RED (wireless); unplug→plug ~1s. Rollback daemon:
  enable xmio-led (no flash needed, but the daemon polarity is
  inverted vs DTB 0x01 — need the inverted v20.3 to come back).

## 65. Round 57 — device_name = 1 single interface; NM dispatcher

- Question: does device_name support both end0 and wlan0? → NO: the kernel keeps
  device_name[IFNAMSIZ], dev_get_by_name takes the whole string (writing "end0 wlan0"
  fails), writing one after the other means the later one overwrites; notify only matches the exact name.
- Zero-poller solution: NM dispatcher script (rootfs has NM +
  dispatcher.d ✓): up/connectivity-change → track the iface that just went active;
  down → if it is the tracked iface, check the other iface for carrier → switch,
  if none, hold → netdev shows RED. Paste at
  /etc/NetworkManager/dispatcher.d/99-led-netdev (chmod +x).
- wlan0 only appears if the wifi chip's driver is in the kernel (vendor
  =y: brcm/rtl...); if the box has wifi but no wlan0 → need to check
  CONFIG_BRCMFMAC/RTL8XXXU against the actual chip.

## 66. Round 58 — user edits the conf by hand; A/B role swap between status/yellow

- User pasted conf: status=netdev(end0,link=1) + yellow=heartbeat, along with the
  wording "yellow handles network, green default-on (boot heartbeat)" —
  config and wording contradict each other → presented 2 options:
  A = the user's conf verbatim (dual LED GREEN/RED by carrier + yellow
  heartbeat blinking alive); B = matching the wording (yellow=netdev network —
  netdev can attach to ANY LED, device_name is independent per LED;
  dual LED=none+brightness1=STEADY GREEN, boot still heartbeat from DTB).
- Mechanism reminder: the conf gets OVERWRITTEN by save.sh at every shutdown from live sysfs
  → hand-editing the conf without changing sysfs = lost at the next power-off.
  Right way: echo into sysfs → shut down once → conf becomes correct on its own.
- ACTIVE_LOW: brightness0 = RED lit (anti-parallel has no off);
  restore.sh skips brightness=0 ✓. brightness under an active trigger
  is ignored by the kernel (harmless).
- If B: dispatcher 99-led-netdev must sed the path over to yellow.

## 67. Round 59 — v22 rootfs: RAM-only logging (debugfs -w lesson)

- User: journal must not use NAND, RAM only, fix the rootfs to reflash.
- Audit of image v15j: journald PERSISTENT (/var/log/journal exists +
  Storage=auto) = heaviest writer; rsyslog enabled (an equal writer);
  sysstat cron every 10 min; chrony driftfile in the same block; fake-hwclock
  once per boot (keep); armbian-ramlog service HAS a unit but is NOT
  enabled (sysinit.wants lacks it), /var/log.hdd does not exist.
- PROCESS LESSON: debugfs defaults to READ-ONLY — every rm/write/sif/
  rmdir must go through `debugfs -w -R`. The 1st run used plain debugfs +
  2>/dev/null → 37376 files before=after, nothing changed, echo "OK" still
  ran because debugfs exits 0. The 2nd run added -w + verify via grep on
  the debugfs output + assert exit 1 on mismatch → a real pass.
- v22 changes: journald.conf +Storage=volatile/RuntimeMaxUse=16M/
  SystemMaxUse=16M/Compress=no; delete /var/log/journal; unlink
  rsyslog from multi-user.wants; delete the cron.d+daily sysstat; chrony
  driftfile → /run/chrony + tmpfiles.d dir rule. fsck clean with 37373
  files (-3 exactly as the theory predicts).
- Deliverable: armbian_rootfs_v22_xmio.img md5
  04f91b9b017f6856f341a6273d04319b @0x17000. Reflashing the rootfs wipes
  the stock LED config → must re-run the Z.11 block. Kernel v21 kept.

## 68. Round 60 — v23: original MAC via vendor storage

- User: the kernel doesn't read a MAC, has to use the 02:31:28:16:01:28 fallback,
  wants the device's real MAC.
- Investigation results (8 rounds of grep): (1) of_get_mac_address priority
  mac-address→local-mac-address→address→nvmem → a hard-coded DTB blocks
  every other path; (2) dwmac-rk has rk_get_eth_addr:
  rk_vendor_read(LAN_MAC_ID=3) → if empty, eth_random_addr + WRITE
  into vendor storage (permanently stable); (3) the backend is ALREADY THERE
  in RK_NAND: rk_nand_blk.c:876 rk_ftl_vendor_storage_init() +
  rk_vendor_register(rk_ftl_vendor_read, rk_ftl_vendor_write) +
  /dev/vendor_storage misc; (4) the only thing missing is
  CONFIG_ROCKCHIP_VENDOR_STORAGE=y; (5) RK_FLASH/nandc NOT needed —
  conflicts with RK_NAND (nandc depends RK_NAND != y).
- v23: config -e ROCKCHIP_VENDOR_STORAGE + DTB v23 (removed
  local-mac-address from v19.4) + zImage rebuild. 5 symbols verified
  in vmlinux. boot 7c5db45984a326c735cc3a51f1e7c6e6 @0xE000,
  resource 832b79f3f0cc3399eaa2a35af0b18582 @0x6800. Z.13.
- Expected dmesg: "rknand vendor storage init ok" +
  "rk_get_eth_addr: mac address: ...". 2 cases: original Android MAC
  (label/router) or random-generated-saved-to-vendor (stable from then on).
- Edge case: if the freshly generated MAC ≠ the stock MAC → can set the stock MAC
  by re-adding local-mac-address with the correct value, or by writing
  vendor storage via the /dev/vendor_storage ioctl.

## 69. Round 61 — MAC arc ends: vendor fails → IDB dead end → label sticker

- On-box v23: `rk_vendor_read failed (-1)` on both read and write;
  `rknand vendor storage init failed !` — the FTL backend doesn't see
  a valid vendor area (stock FTL gen ≠ blob A26). The vendor path is dead.
- Dumped the efuse on the box (nvmem sysfs, the efuse node already present from the stock
  DTB): `52 4b 13 82 79 f0 00 01` + 16B chip ID @7 + leakage @0x17
  — NO MAC in the efuse.
- Stock Android log provided by the user: IDB MAC = 00:00:00:00:00:00
  → IDB empty FROM THE FACTORY, the label sticker is the only source. Kernel
  A26 has no "MAC address from IDB" string (only the stock 3.10 kernel);
  the FTL blob only reads the IDB (FlashReadIdbData/rknand_get_idb_data),
  there is NO write. Writing the IDB = miniloader + boot-area risk → dropped.
- v23.2: local-mac-address = [B8 3D 4E 84 3D A3] (label sticker,
  global OUI) into the gmac DTB. Persistent in flash (boot+resource),
  independent of the rootfs. boot 85be3b158d79591b3fa68e1890900488
  @0xE000, resource f849f2e6de3bc7a117b6346cd09fe326 @0x6800. Z.14.
- Expected dmesg: NO more rk_get_eth_addr (the DT blocks it first);
  the remaining "vendor storage init failed" is harmless (cosmetic).
- Lesson: the RK3128 efuse only holds a chip ID; the factory MAC of this
  box line lives on the sticker, not in any on-chip storage.

## 70. Round 62 — v23.3: MAC persistence at the U-Boot layer (survives all firmware)

- User wants the MAC to survive flashing a DIFFERENT firmware (the
  DTB gets overwritten then). Analysis of the flash layers: IDB/MAC
  unreadable (A26 has no code; writing needs a miniloader), vendor storage dead.
- Discovery in strings uboot-stock: `local-mac-address`,
  `eth%daddr`, `usbethaddr` + the string `%d:%02x:...` = U-Boot has
  fdt_fixup_ethernet(): injects the MAC from the ethaddr env into the DTB before each
  bootm — regardless of which firmware's DTB.
- Default env of the stock uboot: string-table @0x3b1c9:
  bootdelay=0, baudrate=115200, preboot=, verify=n,
  initrd_high=0xffffffff=n (quirk '=n' byte-exact), ends
  before rodata ", \0" @0x3b212 (73B slack). bootcmd=bootrk @0x3b1ba
  KEPT INTACT. Image = 2 identical 512K mirrors → patch both.
- Patch: drop bootdelay/preboot/verify (unused by bootrk),
  insert ethaddr=B8:3D:4E:84:3D:A3 (26B), keep baudrate+initrd_high
  → 67B ≤ 73B. tools/v23.3-uboot-mac.py; verify: mirrors in sync,
  MAC 2/2, bootdelay gone, bootcmd/baudrate/initrd_high intact.
- uboot-planb-mac.img sha256 5e45a5af... @0x2000. Rollback: reflash
  uboot-stock.img. Guide Z.15.
- Design note: for U-Boot to pass the correct MAC into the kernel via the DTB, the
  DTB of later firmware must NOT hard-assign an empty/0
  local-mac-address (fdt_fixup only injects when the node has compatible ethernet...).
  For our firmware: DTB v23.2 already has the sticker-label MAC → consistent;
  DTB v23 (no MAC) → gets it from env — exactly the "different firmware" scenario.

## 71. Round 63 — v24: vendor storage write (deepest flash layer)

- User wants the MAC written into flash, surviving a flash of different firmware
  (even if uboot-env gets overwritten by a different uboot flash). At the same time the user
  confirmed: old Android DID have the MAC → lost after repeated tinkering.
- Decoding the mystery: the 2016 factory wrote the MAC into the IDB (stock kernel log:
  "Read the Ethernet MAC address from IDB"); every full firmware
  upgrade overwrites the IDB (generic miniloader) → the MAC disappeared BEFORE
  the project started. The A26 kernel has no IDB-MAC reading code; the blob only has
  FlashReadIdbData (read). Writing the IDB = dead end (no tool, boot-area
  risk, and it gets overwritten again at the next full flash).
- The right path: VENDOR STORAGE — the FTL's reserved area (4 slots × 128
  blocks, outside every partition, invisible in parameter.txt). The A26 U-Boot
  /vol/uboot-sb: vendor_storage_read/write + board.c:122 ITSELF READS
  LAN_MAC_ID=3 to set ethaddr (and self-generates + WRITES it back if empty) —
  proof of the ecosystem standard. Kernel blob FTL 5.0.63 is the same generation
  as the A26 uboot blob → compatible vendor-area format.
- v24: (1) kernel patch rk_nand_blk.c — register /dev/vendor_storage
  unconditionally (register even if scan fails; backup .orig-v23);
  (2) tools/v24-vendor-mac.c — static ARM tool: ioctl VENDOR_READ/
  WRITE_IO (RK_VENDOR_REQ tag=0x56524551, id=3, len=6) — read →
  write → read-back verify. Cross-build OK (373KB static).
- Flash: boot.img v24 a0aaa1ca576783c877bf89ceede98287 @0xE000;
  resource v23.2 kept as-is. Guide Z.16.
- Empirical test pending: if the blob rejects the write (vendor area completely
  empty) → fallback to v23.3 uboot env. If OK → endurance test: reflash
  boot v23 (DTB without MAC) → end0 still B8:3D:4E:84:3D:A3 from vendor.
- Lesson from the whole MAC arc: RK3128 XMIO has no MAC in efuse;
  IDB-MAC was lost long before; the only remaining origin = the sticker label
  (B8:3D:4E:84:3D:A3, globally-administered OUI). Standard persistence = vendor storage
  (LAN_MAC_ID=3), backup = uboot env, self-contained = DTB.

## 72. Round 64 — v24 CONFIRMED: vendor storage persistence is real

- Box test: write once (v24 tool, verify OK) → flash boot-v23 (DTB
  without MAC, vanilla kernel) → `rknand vendor storage init ok !`
  FOR THE FIRST TIME (always failed before) = the blob write DID format +
  write real flash. → back to v24: the tool reads `b8:3d:4e:84:3d:a3`
  back from flash without writing again. Persistence across reboot + boot
  image swap: CONFIRMED.
- boot-v23 still shows a random MAC (76:9b:93:...) = exactly the probe-order
  limit (gmac 3.4s < nand 5.5s), NOT a MAC lost from flash.
- Flash flow of boot.img: the DTB lives inside boot.img (second/resource)
  — flashing the resource partition separately does NOT affect the DTB the boot
  uses (bootrk reads from boot.img). testimg already verified this behavior.

## 73. Round 65 — v24.1: MAC fully vendor-driven, no DTB hardcoding

- User: "vendor only, no more dtb hardcoding — flashing via a different
  box gives the same mac as the old box". Correct: local-mac-address is per-IMAGE.
  uboot-planb-mac (env) has the same problem → DEPRECATED.
- v24.1 = DTB v23 (no MAC) + dwmac-rk patch: the gmac probe returns
  -EPROBE_DEFER when the DTB has no MAC && !is_rk_vendor_ready() (bounded
  64 defers → a new, not-yet-written box still boots random normally).
  The include rk_vendor_storage.h was already present in dwmac-rk.c.
- Repack: resource.img goes back to `832b79f3…` (same as v23 — reproduced
  byte-exact); boot.img `6e4aeb49…`. MAC-in-DTB backup:
  resource.img.v23.2-mac.bak. Guide Z.17.
- Expected v24.1 dmesg: gmac defer at ~3.3s (silent), "vendor
  storage init ok" ~5.5s, re-probe → "rk_get_eth_addr: mac address:
  b8:3d:4e:84:3d:a3" → "device MAC address ..." ~5.6s, before NM
  open (~17s).
- Final matrix: planb = DTB-vendor both yield B8; A26 chain = uboot reads
  vendor; new box = random → vendor-mac written once; stock 3.10 = IDB
  dead-end (accepted).

## 74. Round 66 — output/ cleanup

- parameter.txt := NATIVE (what the user is using; the only difference from the old copy:
  native does NOT have `video=HDMI-A-1:1920x1080@60e`). The old variants
  (badnand1/v14diag/v16 — v16 matches native md5) → archive/.
- Deleted: v15j rootfs (1.1G, replaced by v22), xmio-sd-2g.img (2.0G,
  built under the wrong "no SD slot" assumption [CORRECTED: the slot works,
  re-creatable via `tools/make-sd-image.sh`]), boot-v23.img (16M, test done —
  rebuild with planb-v23-testimg.sh), misc.img.bak, initrd
  orig-A26, base64 chunks, old bundle.
- Archive/ (not deleted, only moved): uboot-planb-mac.img (DEPRECATED),
  resource.img.v23.2-mac.bak, resource-baseline.img, parameter
  variants.
- v26.2 rootfs: md5 output (aa1a26fb) DIFFERS from A26-release (b3bc9279)
  → keep both.
- STUCK: the v15 rootfs img (1.1G) is held by a Windows process (cannot
  delete/write/rename/truncate it; no fd holds it inside the container).
  Fix: restart Docker Desktop (or the machine) then delete. Space:
  6.6GB → 3.4GB (~2.3GB will remain after deleting v15).
- New bundle: XMIO-bundle.tar.gz 59MB (was 78MB); SHA256SUMS planb
  13/13 OK. onbox keeps vendor-mac + xmio-led v20.2 (md5 cross-checked
  ee3fa38a) + service; the v20.1 binary was deleted.

## 75. Round 67-68 — v24.2: /proc/cpuinfo (Hardware + Serial)

- User's question: cpuinfo doesn't show RK3128 correctly. Diagnosis in 3 lines:
  (1) model name = the CORE name from MIDR (arm32 by-design; 0xc07 =
  Cortex-A7 rev 5 — correct RK3128), no fix needed; (2) Hardware
  "Generic DT based system" = mach-rockchip dt_compat missing rk3128;
  (3) Serial 0 = setup.c kasprintf makes the string TOO EARLY before
  rockchip-cpuinfo probe computes crc32 of the chip-ID → c_show reads the string
  stale (system_serial_low/high already set but string cache 0).
- CORRECTING MY OWN MISDIAGNOSIS: grep on v25c for the line "2234:
  compatible = rockchip,cpuinfo" is a MATCH from DTS (misread as
  .c) — the cpuinfo node is ALREADY PRESENT in the DTB since v23 (stock A26
  inheritance); resource md5 832b79f3 unchanged across
  v23/v24.1/v24.2 is the proof. Lesson: verify by decompiling the
  shipped blob + mtime, don't trust one-way grep context.
- v24.2 = 2 kernel patches (rockchip.c dt_compat +"rockchip,rk3128";
  rockchip-cpuinfo.c overwrites system_serial after crc32) — DTB NOT
  changed (v24.2-dts.py no-op idempotent). CONFIG_NO_GKI=y already there.
  rockchip_soc_id_init:337 has an rk3128 branch (sets ROCKCHIP_SOC_RK3128).
- Machine switch is safe: GENERIC_DT and ROCKCHIP_DT both have no .smp,
  init_time equivalent (rk3288-only branch gets skipped), l2c same.
- Flash: ONLY boot 468c5d940187bfbd6cfd9dd6abc55171 @0xE000
  (resource unchanged). Expectation: Hardware "Rockchip (Device Tree)",
  Serial 16-hex per-device (crc32 of efuse chip-ID), dmesg "SoC : ..."
  + Serial; MAC/LED unchanged. initcall_blacklist=rockchip_cpuinfo_
  init = no-op on 6.6, leave the parameter as is.

## 78. Round 71 — v24.3: LEDs pre-configured (green default-on, yellow wlan0)

- User settled the roles: green default-on (NO more heartbeat), yellow netdev
  wlan0 → this also settles the Option A/B question left hanging since Round 60.
- netdev trigger 6.6 evidence: set_device_name ACCEPTS a device that
  doesn't exist yet (it only stores the string, dev_get_by_name NULL → net_dev NULL,
  return 0) + netdev_trig_notify binds by name at NETDEV_REGISTER
  (strcmp dev->name vs device_name) → arm-once is enough, no dispatcher.
- DTB v24.3: status-led drops heartbeat, default-state = "on" (green
  lit ~2s, ACTIVE_LOW pin low = green). io-led unchanged.
- Rootfs v23 = copy of v22 + debugfs -w: script
  /usr/local/sbin/xmio-led-green (none+brightness=1 for green; netdev
  + device_name=wlan0 + link/rx/tx=1 for yellow) + sysinit unit
  (DefaultDependencies=no, After=systemd-modules-load,
  Before=sysinit.target) + debugfs `symlink` into
  sysinit.target.wants. v22 kept as rollback.
- Wifi: chip = esp8089 (wifi_chip_type in the DTB), CONFIG_ESP8089=m
  + module in rockchip_wlan/rkwifi, SDIO host 0x92 status okay.
  LEDtrigger NETDEV =y (built-in) → no dependency on modprobe.
- debugfs: `write` keeps the source mode (script created 0755 → inode 0755);
  the `sif: read/only` message is harmless; `symlink` command OK (target
  42 bytes verified via stat).
- Bug assert: decompiled gpio = `0x08` zero-padded (not `8`)
  — use regex `(?:0x0?8|8)` as in previous rounds.
- Flash 3 files: boot 5f61edcd @0xE000, resource b12893c9 @0x6800,
  rootfs v23 485fb7d6 @0x17000. Guide Z.19.

## 79. Round 72 — user changes direction: ONLY armbian-led-state

- User: "use only armbian-led-state, no kernel changes, no
  xmio-led-green". Scrap the custom service design.
- Dissected the stock scripts in the rootfs (cat via debugfs): save.sh saves
  ALL writable params (device_name/link/rx/tx of netdev are all
  saved — the old Round 49 guess "only trigger+brightness" is wrong for
  this build); restore.sh writes in the exact order, one quirk: brightness=0 gets skipped,
  trigger=none must write default-on first. Conclusion: netdev wlan0
  PERSISTS across reboots with ALS alone — the right tool, as the user chose.
- Finding: the ALS enable is ALREADY in the stock rootfs at
  basic.target.wants (last time I checked multi-user.target.wants →
  wrongly concluded "not enabled").
- Modified rootfs v23 (new md5 3a9abd13): removed xmio-led-green (script+unit
  +sysinit symlink — verified gone), seeded /etc/armbian-leds.conf
  (green none+brightness=1; yellow netdev wlan0 link/rx/tx=1) so the first
  boot is ALREADY correct without waiting for shutdown.
- DTB v24.3 untouched (default-state on for green — the
  default state before restore; not kernel code). boot
  5f61edcd / resource b12893c9 unchanged.
- Self-inflicted bug: pipefail + debugfs stat on a missing file killed the script
  mid-verify (file missing = the expected outcome) → use explicit || echo.

## 76. Round 69 — /boot in the rootfs when the kernel is separate

- The real boot chain: stock uboot `bootrk` reads boot NAND @0xE000 +
  resource, never mounts ext4 → /boot is INERT at boot time.
  boot.scr/boot.cmd/armbianEnv.txt/uInitrd/boot.bmp = leftovers of the
  standard Armbian flow (uboot reads from fs) — not used.
- Remaining value (verified on v22): System.map + config (kallsyms,
  perf, oops cross-checking) — keep; vmlinuz-…+ = the original build output (matches
  output/kernel/zImage); initrd.img-…+ = the source for repacking boot.img
  (note: differs by 206B from the initrd being flashed — built at a different time).
- WARNING: dtb/ in /boot is STALE (old v1x build) — the live DTB sits in
  resource.img. apt kernel update / update-initramfs writes /boot
  "successfully" but does NOT change the booting kernel — must repack
  boot.img from those files and flash @0xE000 for it to take effect.
- Future: kexec -l /boot/vmlinuz-new = test a kernel without
  reflashing NAND — /boot would get a real role if going this way.
- flash-kernel not installed → apt won't touch the boot flow on its own. /boot 31MB
  in the 3.6GB rootfs — no cleanup needed.

## 77. Round 70 — architecture summary: uboot is the root of every workaround

- Correct: stock uboot 2016 `bootrk` = the bottleneck that dictates the format.
  Hardcoded: kernel from boot NAND in the KRNL/resource wrapper (bootimg
  header), DTB from --second, cmdline from baseparamer; does NOT read
  ext4/extlinux/boot.scr → all of /boot inside the rootfs is inert;
  must mkbootimg + pack_resource instead of copying files like a distro.
- Proof the DTB travels with boot.img (not with the resource flash):
  boot-v23 test — the embedded resource wins, gMAC random even though the
  resource partition has a different DTB.
- MAC persistence is also down to uboot: stock doesn't read vendor storage →
  only the A26 chain reads LAN_MAC_ID; the hardcoded uboot-env fix is ruled out because
  per-image; vendor storage = the right layer.
- Why stock uboot is KEPT ON PURPOSE: brick risk concentrates in the
  uboot/IDB region; no proven SD-boot rescue path existed at this point
  [CORRECTED: the box has an SD slot; only the SD-boot path was untested];
  stock is proven to boot on
  this box; all experiments live in boot/resource/rootfs = recoverable.
  A deliberate tradeoff: the messy vendor format in exchange for absolute
  recoverability. With a modern uboot (extlinux/distro boot): just
  copy vmlinuz+dtb+initrd into /boot + extlinux.conf — no
  mkbootimg, no pack_resource, and /boot comes back to life.

## 80. Round 73 — rebuilding U-Boot from source: FEASIBLE (uboot-v1)

- User question: without the XMIO SDK, can a uboot built "standard like the port"
  have enough features + stay compatible with uart/hard keys?
- Key finding: repos/u-boot-rk3128-tvbox (chieunhatnang-
  personal) = newer Rockchip BSP U-Boot 2017.09 (boards up to rk3588) already
  ports RK3128; it is the ORIGIN SOURCE of the A26 uboot: (1) the defconfig has the comment
  "# Chieunhatnang's modification" (DEBUG_UART_BASE=0x20064000 uart1
  — matches the FLASH-GUIDE note); (2) the A26 banner 2017.09-g53cd91b73c-
  250620-dirty = the commit BEFORE 218938c "Ad support for eMMC device as
  boot device" of the repo; (3) board.c:122 vendor_storage_read(
  LAN_MAC_ID) exactly on the line NOTES records.
- Distinguishing the 3 uboots on flash: MD5 of stock Android 0c9788a3 =
  uboot-stock.img (currently running on the box, banner 2014.10 Mar 2015 —
  the GENUINE uboot is running); MD5 9c070f6e = uboot.img A26 2017.09
  (A26 file but NOT yet flashed); uboot-planb-mac (deprecated).
- Out-of-tree build: /vol/uboot-src (copy of repos/…) + O=/vol/uboot-build
  CROSS=gcc-arm-10.3 (prefix arm-none-linux-gnueabihf-, NOT
  arm-linux-gnueabihf-): make rk3128_defconfig + make -j: OK on the
  first try, u-boot.bin 836496B (A26 payload 839104B). First-run errors: $(nproc)
  swallowed by PowerShell → script via file; wrong toolchain prefix.
- .config feature parity after resolve: RKNAND, RKPARM_PARTITION,
  ROCKCHIP_VENDOR_PARTITION, ADC_KEY/GPIO_KEY/DM_KEY/RK_KEY,
  CMD_BOOT_ANDROID/BOOT_ROCKCHIP, ANDROID_BOOTLOADER, FASTBOOT
  (flash+download), MMC_DW_ROCKCHIP, OPTEE_CLIENT, USING_KERNEL_DTB=n
  (=A26), DEBUG_UART_BASE=0x20064000.
- Pack: tools/rkbin (clone of rockchip-linux/rkbin) loaderimage
  --pack --uboot u-boot.bin uboot.img 0x60000000 (TEXT_BASE from
  rk3128_common.h; loaderimage pads 4MiB on its own). tools/uboot-v1-*.sh:
  build/pack/featurecheck. output/planb-uboot-v1/: uboot-v1.img
  d87d2762 + u-boot-v1.bin ccbcaeaa + dtb/config/log.
- RKIMG bootcmd: boot_android (needs vbmeta — fails fast) → boot_fit
  (fails) → bootrkp (reads the parameter.txt CURRENTLY flashed — on the box
  that is native: boot@0xE000 → boot.img v24.x as in the current chain) →
  distro_bootcmd. NO test-flash (brick risk; the proven rescue is a USB
  reflash — [CORRECTED: the box has an SD slot, an SD-boot rescue was simply
  untested at this point]) —
  deliverable awaiting the user's decision; Plan B rollback = reflash
  uboot-stock.img 0c9788a3 @0x2000 (1 file, via MaskROM).
- XMIO SDK NOT needed: all compatibility lives in the DTS (v24.3 already present) +
  defconfig; the uboot BSP contains no XMIO-specific board code —
  the A26 chain also runs DTB-based throughout.
- Left open for the future: if the test passes in loader mode → could build
  a USING_KERNEL_DTB=y variant (using the embedded DTB) or distro-boot
  (extlinux) — but NOT mandatory; stock uboot remains the safe
  default.
- User question "stock 1MiB vs 4MiB, is the partition OK": dissecting
  the header (tools/uboot-format-check.sh) → all 3 files share the same container
  "LOADER  " (2KB header: magic + load-addr + size + CRC): stock
  load 0x60200000 size 301.784B flag 0x14 (header+code+pad 512K,
  mirror ×2 against bad blocks); A26/uboot-v1 load 0x60000000,
  size 839.104/836.496B flag 0x20, loaderimage pads 4MiB. Partition
  uboot 0x2000@0x2000 = 4MiB in BOTH native and A26 → the 4MiB file fits
  exactly, ends right at 0x4000, does not overwrite misc. The loader in IDB reads
  size/addr FROM THE HEADER (the box is booting a factory headered uboot =
  proof the loader parses the header) → file size is not
  the issue; a payload >512K needs a header-reading loader = v2.12.263
  (the Loader tab step is mandatory — A26 proves the same pairing). Limits:
  the file @0x2000 must not exceed 4MiB; Plan B does not flash trust @0x4000.

## 81. Round 75-76 — v1 flash-test DEAD; user corrections; unshallowed repo; uboot-v2 from the correct A26 base

- v1 flash @0x2000 (loader V2.25, Loader tab): NO boot — no
  UART, no button, no network. User rescued it by reflashing; then
  corrected 2 points, both TRUE and backed by commit evidence:
  (1) the hardware button belongs to uboot — commit 62a6711e48 "Add support for
  reset button: Holding will boot into Maskrom mode" (Mar 2026,
  board file evb-rk3128.c 299 lines + &saradc okay in the DTS; reads
  ADC ch1, RK3128_MASKROM_ADC_MAX=30 — a calibration threshold tuned to the AUTHOR's
  board, may not match the XMIO button voltage → explains why A26
  boots OK but the button does not work);
  (2) A26 DID really boot on the box (network up + DHCP offered). [FIXED
  in §82: the conclusions "the factory miniloader V2.25 in IDB can load
  uboot 2017" and "the flash-session loader is not in IDB" are WRONG — the Loader
  tab EraseFlash+Download WRITES the loader into IDB, and the old A26 test used
  loader v2.12.263.] Also FIXED the Z.20 claim that "loader v2.12.263
  is mandatory because payload >512K" (wrong — the flash-session loader does not sit
  in IDB, unrelated to boot).
- Unshallowed the repo (shallow clone, 54.864 commits): 53cd91b73c EXISTS,
  IS an ancestor of HEAD. Diff HEAD vs 53cd91b73c = exactly commit
  218938c "Ad support for eMMC device as boot device" +313/-5
  (storage_rk3128.c 196 new lines, dw_mmc 44, rknand 18, rockchip_
  nand 16, nand_spl 17, boot flow). V1 = A26 base + eMMC patch →
  SUSPECT #1 for v1's death: the eMMC patch changes the boot flow before
  the NAND-first boot completes (the box has no eMMC).
- HW compat verify before the v2 build: v1 embedded DTB ≡ A26 IDENTICAL
  (diff 0) — uart1 stdout 20064000, pinmux GPIO1_A9/A10 func2 matches
  XMIO; board_debug_uart_init present in the binary; the DTB has NO
  key node (the key function lives in the board file code, no DTB key
  node needed); v2 banner after build = 53cd91b73c-250620 (matches A26, missing
  -dirty = the author's ~3KB of uncommitted local changes).
- uboot-v2 = git worktree @53cd91b73c clean build (tools/uboot-v2-
  build.sh): payload 836.088B, uboot-v2.img ca015870 @output/
  planb-uboot-v2/. Matrix: A26(base, dirty)=boots OK; v1(HEAD,
  +eMMC)=dead; v2(base, clean)=awaiting test. If v2 works → pin the root
  cause = the eMMC patch; if v2 is dead → the cause lies in the author's -dirty
  local part (not reproducible from git) or another variable
  (keep stock as the default).

## 82. Round 77 — v2 still dead; model fixed: the IDB loader is the variable; TEST C/D

- v2 (pristine A26 base, NO eMMC patch) flashed @0x2000 with the
  same loader V2.25 → STILL NO boot → the eMMC patch is RULED OUT as the
  cause. My blind spot exposed: "the Loader tab only loads a loader for the flash
  session, not in IDB" (§81) WRONG — the Loader tab EraseFlash+Download
  WRITES that loader into IDB; section B always specifies
  rk3128_loader_v2.12.263.bin → every flash per the guide had IDB = 263.
  The v1/v2 test used the MiniLoaderAll V2.25 loader (stock) → IDB switched
  to V2.25 → only then were we in the IDB V2.25 + uboot 2017 state for the FIRST time.
- Loader generations (build-year field in the header): MiniLoaderAll V2.25
  = 2015-era (0x7df) — created for uboot 2014 flag 0x14, payload
  302KB/mirror 512K; v2.12.263 = 2026-era (0x7ea) — ships with A26,
  can read uboot 2017 flag 0x20 payload ~839KB (A26 booting OK on
  this very box = the proof). The 5-cell matrix matches 100%: (263,stock2014)=
  booted all project long; (263,A26)=booted on first try; (V2.25,stock2014)=boot
  rollback; (V2.25,v1)=dead; (V2.25,v2)=dead. Plausible mechanisms:
  V2.25 only reads a 512K window (mirror era) → the 836KB payload gets
  cut off, CRC fails; or it does not recognize flag 0x20.
- HARDWARE is NOT the cause of the death symptom: v2 embedded DTB ≡
  A26 byte for byte (A26 did boot on this very box); a silent UART also happens
  with A26 (the uboot 2017 console = UART1; the pads are probably UART2, where
  the kernel prints its log) — silent ≠ dead; button = ADC threshold ≤30 (author's board,
  commit 62a6711e48) not yet matched to XMIO — affects A26 and v2 alike.
- TEST C (Z.22): Loader tab loads v2.12.263.bin with EraseFlash+Download
  (writes IDB) → flash uboot-v2.img @0x2000 → expect network+DHCP as in
  the A26 round. TEST D if C dies: flash the real A26 9c070f6e @0x2000 (first
  TIME testing A26 on the native layout; loader 263) — alive = only the
  author's ~3KB "-dirty" local changes remain (not in git); dead = A26
  only survives on the A26 layout → STOP, keep the stock uboot permanently.
- After every test: restore uboot-stock 0c9788a3 @0x2000 (loader 263
  works fine with stock — the whole project is the proof) → the v24.x chain as before.

## 83. Round 78 — user's background question + uboot-v3 (UART2 + channel-2 key)

- User asked the background question: "uboot only handles booting; if built
  correctly for the hardware it must be interactable via UART or keys; how to
  make it compatible? does uboot need a device tree different from the kernel?" — correct, and led
  to a major finding: the DTB embedded in uboot uses the GENERIC rk3128-evb,
  stdout=serial1 (UART1); XMIO routes the console out to UART2 (serial@20068000,
  pinmux uart2-xfer GPIO1_C2/C3 func2, kernel DTS uart2-xfer <0x01
  0x12 0x02 0x66 0x01 0x13 0x02 0x65>) → the A26/2017 uboot is SILENT NOT
  BECAUSE IT DIED but because the console sits on UART1 (does not reach the pads). Cross-check:
  A26 boot OK (network+DHCP) despite a silent UART — matches.
- Bonus finding: the author ALREADY had a uart2 branch written in
  board_debug_uart_init (arch/arm/mach-rockchip/rk3128/rk3128.c
  #else branch: gpio1c_iomux GPIO1C2_UART2_TX/C3_RX; comment in
  defconfig: "0x20068000 for uart2 and that is the most important
  part") — only defconfig + DTS needed changing.
- Pin CONFLICT: GPIO1C2/C3 = sdmmc_bus1 (func1) COLLIDES with uart2_xfer
  (func2) → an sdmmc probe would flip the pinmux and kill the console. XMIO has no
  SD/eMMC → &sdmmc + &emmc disabled in the uboot DTS.
- The XMIO key = SARADC CHANNEL 2 (kernel DTS adc-keys io-channel <&saradc
  2>): VolUp press 0uV (keyup 3.3MµV → raw ~0), VolDown 1.65V,
  home 2.33V, back 2.93V. The uboot code reads channel 1 with threshold ≤30 → change
  RK3128_MASKROM_ADC_CH 1→2; threshold ≤30 raw ≈ 0.145V matches VolUp
  (0µV) = the loaderXMIO key is likely VolUp.
- uboot-v3 build: worktree @53cd91b73c + 4 patches (defconfig uart2;
  DTS uart2 okay + chosen serial2 + sdmmc/emmc disabled; ADC_CH 2);
  transient toolchain-not-found twice (Docker Desktop mount hiccup —
  the file exists, direct exec OK, retry done); script died at the grep
  verify (set -e) but build + DTB OK; packed separately → uboot-v3.img
  7020d582 (4MiB), u-boot-v3.bin 1c784930 (836.072B). DTB verification:
  serial2 okay/chosen serial2/sdmmc+emmc disabled/saradc okay ✓.
  Banner 2017.09-g53cd91b73c-250620-dirty (dirty = our patches).
- T1 expectation (flash v3, loader 263): FIRST TIME the UART pads print a
  banner (regardless of whether uboot hangs afterwards — the problem may be
  broken into smaller pieces). If it stays completely silent → no hardware/
  configuration suspects remain → stop, keep stock uboot permanently.
- Answer to "does uboot need a DTB different from the kernel's": correct in PRINCIPLE (uboot
  has its own DTB for itself: console, early pinmux, memory, mmc; the kernel
  has its own DTB for kernel drivers) — BUT here the 2 DTBs match or the pinmux
  matches → 2 real damages: (1) stdout mistakenly on UART1; (2) the sdmmc
  probe overwrites the UART2 pinmux. Both fixed in v3.

## 84. Round 79 — v3 silent (loader 263 confirmed); 2 suspects left; v4 with the author's toolchain

- User confirmed T1 used loader v2.12.263 → the IDB is of the proven generation
  → v3 silent = binary died BEFORE the banner. Exclusion summary (8 items,
  see Z.24): wrong console pins ✗, DTB ✗, loader ✗, eMMC patch ✗,
  defconfig ✗, partition/format ✗, OPTEE/TOS pre-reloc ✗ (grep 0
  matches in mach-rk3128 + evb board; trust is the MINILOADER's job
  per the parameter, uboot does not load it — spl_rkfw is only used for update.img).
- 2 suspects remain INSIDE the binary: (1) toolchain — every build of ours
  used gcc-arm-10.3, A26 (the only one alive) was built with gcc-linaro-6.3.1-2017.05
  arm-linux-gnueabihf (make.sh CROSS_COMPILE_ARM32 states it explicitly); uboot
  2017 + a newer GCC = the classic early-crash. (2) "-dirty" ~3KB of local
  author changes (the banner certifies it) — not in git.
- v4 = v3 patches + linaro 6.3.1: dead releases.linaro.org link (58KB
  HTML page), replaced with the gitlab.com/firefly-linux/prebuilts mirror →
  gcc (Linaro GCC 6.3-2017.05) 6.3.1 at /vol/toolchain-linaro. Build
  OK (tools/uboot-v4-build2.sh), uboot-v4.img 53109877 @output/
  planb-uboot-v4/. Note: PowerShell $? interpolation made "V4=True" —
  the docker exec exit code is unreliable, must read the log.
- T2 = flash v4 (loader 263): banner → toolchain settled, keep
  debugging on the console; silent → stop experimenting, ask the author (draft
  AUTHOR-REQUEST-draft.md in output/planb-uboot-v4/ — ask for the dirty
  diff + toolchain confirm + build steps).
- Backup Plan C (if needed later): misc.img + baseparamer-720P.img
  available in work/stock-rkunpack/Image/ → the native layout can be fully
  reproduced after any layout experiment.

## 85. Round 80 — BIG ALARM: the author's full flash also just blinks; A26-DHCP downgraded; v5 the final note

- User T2b (done themselves): loader 263 + v4 + A26 parameter + trust + our root
  → network LED LIT + BLINKING but NO UART/keys/DHCP/armbian.
  SHOCK: reflashing the author's ENTIRE original build → EXACTLY THE SAME
  result (blinking LED, no DHCP). → A26 is no longer "the binary once proven
  to boot DHCP" — the DHCP event happened MONTHS EARLIER, on a
  different flash/IDB/FTL state. Current state: the genuine 2017 binary
  also fails to pass some gate lying BEFORE the console (blinking = the Code
  has run to where ethernet-light turns on, or the kernel reset-loops —
  indistinguishable, but definitely MORE ALIVE than "LED fully off").
- Model implication: the problem is NO LONGER "wrong build" — it is "the path
  to restore the current flash". 7 evidence items (Z.25): flash integrity ✓
  (stock rollback always survives, update.img contains the 2017 uboot on the same
  flash path), FTL ✓, IDB 263 ✓ (enough to enter Loader mode), DRAM-263 ✓, trust/
  param complete ✓ (T2b), MiniLoader V2.25 ✓, KLU wires/cables ✓. What remains:
  something older than the miniloader or between-the-two-stages — not flashable.
- V2.25 vs 263 is still a REAL observable variable (2 constants of 2026 comparing
  the header year-field 0x7df vs 0x7ea) — not made up.
- v5 = v4 + ADC_MAX 30→1000 (every XMIO key triggers at 0–911 raw, release
  1023; sed 5' patch). Payload 839.016B ≈ A26 839.104 (linaro codegen
  close to the author's). uboot-v5.img 09461a82 @output/planb-uboot-v5/.
- Final T3 (Z.25): restore native FIRST (native param + misc +
  baseparamer + resource + boot + uboot-stock; keep rootfs), SSH OK →
  flash v5 @0x2000: LED BLINKING = uboot alive (keep the key to read behavior);
  LED OFF = identical to every 2017 binary → STOP. STOP = stock permanently.
- User decision: "stop working on uboot if this attempt fails"
  → after T3, whichever the outcome: close the uboot arc, keep the v24.x chain as
  the official product.

## 86. Round 81 — T3 = LED OFF → UBOOT ARC CLOSED (per the user's commitment)

- T3 on a clean native base (native param + misc + baseparamer +
  resource + boot + stock, flashed by the user beforehand): v5 @0x2000 →
  NO network LED, keys unresponsive → the STOP branch. The five
  2017 binaries (v1 gcc / v2 gcc-base / v3 gcc+uart2 / v4 linaro / v5
  linaro+key1000) + genuine A26 (T2b) all stopped at the same wall
  (A26: blinking LED — the only sign of life but no DHCP).
- Final verdict: the wall sits in a layer older than the miniloader or between
  the two stages — unreachable by flashing; every software suspect
  has been eliminated (Z.20–Z.25); no UART output from the 2017 generation
  on this box → on-device debugging impossible from outside. Box: restore
  1 file, uboot-stock @0x2000 → the v24.x chain as before.
- Legacy kept: output/planb-uboot-v1..v5 (binary+config+log),
  AUTHOR-REQUEST-draft.md (v4), toolchain-linaro + unshallowed repo +
  tools/uboot-* scripts (reproducible in minutes), Z.20–Z.26 + §80–§86
  (matrix + lessons: the IDB loader is the real boot variable; the pinmux is
  shared by UART2/sdmmc; channel-2 ADC-key binding; experimental
  limits of RK3128 NAND-only flashing).
- Project status: the v24.x chain (boot 5f61edcd / resource b12893c9
  / rootfs v23 3a9abd13 + uboot-stock 0c9788a3) = the main product
  product, unchanged. Old pending items remain open: verify on-box v24.3b
  (cpuinfo Hardware/Serial, green/yellow LED + ALS persistence, presence
  of wlan0), delete output/armbian_rootfs_v15_xmio.img (locked file),
  answer the background IO cause (waiting for the user's iostat/iotop output).
  [Correction: HDMI is NOT pending — settled as OK native mode
  at Round 41 (§49).]

## 87. Round 83 — v24.4: no-eth0 after reflash = v24 defer patch bug + vendor dead after EraseFlash

- Symptom after the user re-flashed the chain: boot OK, `ip a` has
  no eth0; dmesg: 3 gmac lines repeating at 3.36/4.85/4.89/4.91/15.28s
  then `deferred probe pending`. Kernel #23, rootfs v23 alive (boot
  OK) → not a flash-file error; shipped DTB decompile ≡ v23
  (gmac node intact, LED patch untouched).
- Root cause (2 layers):
  1) The v24 MAC patch in dwmac-rk.c defers gmac until
     `is_rk_vendor_ready()`; escape = counter 64 times. BUT the core
     deferred-probe in 6.6 stops retrying after `driver_deferred_probe_
     timeout` (~15s — `deferred_probe_timeout_work_func` lands in
     "deferred probe pending" then freezes) → only ~5 attempts
     → the counter never reaches 64 → eth0 never
     appears. My design mistake: the counter should have been a time deadline.
  2) Session T2b used the Loader tab v2.12.263 = EraseFlash of the whole NAND
     → the vendor storage area (FTL reserved, OUTSIDE every partition,
     §71) got erased; re-flashing partitions cannot restore it →
     `rk_ftl_vendor_storage_init()` fails → `_vendor_read = NULL`
     → defers forever. Before this arc: vendor alive (v24 wrote it once, §72) so
     the same boot.img still had eth0 — everything else identical.
- v24.4 fix (user request: random on failure + vendor-mac into rootfs):
  - Kernel #24: blocking wait 10s (`msleep 100×100` in probe —
    immune to the freeze because it is not on the deferred list; rk_nand does
    not depend on gmac → no deadlock) then warn + random. Verify:
    strings vmlinux contains "not ready after %ums", counter symbol gone.
  - rootfs v23.1 (`c43f8c56…`, debugfs inject): `/usr/local/sbin/
    vendor-mac` rebuilt + mode `show` (read-only), `vendor-mac-apply`
    (vendor present → use it; empty/corrupt → write the label MAC
    B8:3D:4E:84:3D:A3 — attempts to revive vendor per §72; apply live
    via `ip link set address` for ifaces whose driver is *dwmac*), unit
    `vendor-mac.service` @sysinit.target.wants, always exit 0.
  - boot.img v24.4 `70d473d8d2d1aa36d2a35ba8d73f76d0` @0xE000
    (zImage `a178396a…`; kernel-in-boot match True; RAM layout OK;
    backup v24.3 → `output/archive/boot-v24.3.img`). resource
    b12893c9 LEFT INTACT (DTB unchanged).
- On-box expectation: boot → random eth0 within ≤10s when vendor is dead →
  service sets the label MAC live; if FTL accepts the write → boot shows
  `init ok` + label-MAC eth0 straight from the kernel. dmesg to watch for:
  `rk_gmac: vendor storage not ready after 10000ms`.
- Lessons: (1) the escape hatch of any defer-loop must be based
  on time (jiffies/deadline), NOT on counting attempts — the core freezes on its own;
  (2) the vendor area = FTL-reserved outside partitions → EVERY EraseFlash
  erases it; a "vendor-layer MAC" does not survive a full erase (unlike the
  §71 design which noted "fallback uboot env" — this fallback is now
  layer 3 after the rootfs service).
- On-box v24.4a round 1 (user): boot 1 random gmac 02:f6:… →
  service wrote vendor OK (ioctl auto-created the area) + set live b8:3d:…
  → DHCP .4; boot 2 reboot: `init ok` @17.45s = area PERSISTS
  (§72 replay, 2nd time). But still random: the 10s cap-wait race
  (lost) vs FTL vendor scan ~12s (init ok 17.45s). v24.4b:
  cap 10s→20s (boot.img 82c2e4e0…, zImage 3640069c…, backup
  boot-v24.4a.img) + v23.2 (657da568…, CLEAN build from v23 —
  debugfs write does NOT overwrite an existing file: "Ext2 file already
  exists" silently leaves the md5 unchanged; must rm + copy again) with
  the apply-script waiting up to 60s for a dwmac iface before applying.
- Additional lessons: (3) debugfs -w write on an existing file
  FAILS silently — always verify the content (grep the new string) after
  inject; (4) vendor-init timing depends on NAND → every wait cap
  must be > the measured worst case (17.45s → cap 20s).
- Round 4 RCA (user correctly pointed out: "earlier kernels read the MAC fine,
  only this one races"): the blocking msleep in the gmac probe occupies
  the SINGLE-THREADED deferred-probe thread → rk_nand behind it gets starved →
  "init ok" always appears ~2s AFTER the gmac gives up (15.5→17.45,
  27.6→29.54: a fixed +2.0s fingerprint). The old Kernel #23 never
  raced because yield releases the thread → rk_nand inits in ~2s → core
  requeues gmac. v24.4c: yield + delayed work 2s + device_attach()
  (self-driven retry since the core freezes after ~15s) + 30s deadline.
  Lesson (5): in probe DO NOT block-wait for another driver on the same
  deferred-probe queue — yield is the right design; the escape hatch
  must drive itself (work/timer), never rely on the core requeueing forever.
- Correction to §88 lesson (4): "FTL vendor scan 12–22s" was an ARTIFACT
  of starvation caused by the blocking-wait itself (rk_nand only got
  to run after the gmac gave up); the real init time is ~2s as in
  older kernels. v24.4b (cap 10s→20s) went the WRONG way — v24.4c
  (yield + self-retry) is the right design.

## 89. Round 84 — closing out the open checklist (user decisions)

- (1) cpuinfo on-box PASS: `Hardware : Rockchip (Device Tree)`,
  `Revision : 0000`, `Serial : 0000000000000000` — matches the expected
  DT-boot (machine desc from DT, no ATAG serial) → CLOSED.
- (2) Yellow LED `netdev device_name=wlan0` (box has no wlan0):
  the user decided to LEAVE IT AS IS — no rootfs change → CLOSED (user's
  will, not technical).
- (3) Background IO 153/113 kB/s: user confirmed IMPROVED →
  CLOSED, no need for iotop/task_delayacct.
- (4) AUTHOR-REQUEST-draft.md (uboot author): user DROPPED it — file already
  deleted from output/planb-uboot-v4/ → CLOSED.
- The only item still open: on-box boot test of v24.4c (f1e30989… @0xE000,
  kernel #26 yield+reprobe) — expecting permaddr b8:3d:… native,
  no random; if it passes, the MAC arc is fully settled.

## 90. Round 85 — HDMI regression report (no RCA yet)

- User: "back to hdmi, I retested and it seems it doesn't work".
  The last time HDMI verified OK was §48–49 (v18.1 native mode, user signed
  off "stable"). Since then kernel v19→v24.4c rebuilt many times, rootfs v23.2,
  HDMI never retested.
- Static audit of the shipping config — NO static regression found:
  (1) the V18HPD poll patch is still in inno_hdmi.c (line 889);
  (2) DRM/DRM_ROCKCHIP/DRM_LIMA =y built-in (kernel 6.6.89-rk3128);
  (3) shipped DTB b218d71d (inside resource b12893c9): hdmi@20034000
  status=okay + ports + route_hdmi + vop okay — same as the v23.2 source;
  (4) boot v24.4c cmdline empty (native, no video= force);
  (5) parameter.txt = parameter.txt.native (both native).
- Not enough data for an RCA yet — waiting for the on-box report. Triage questions:
  does the box fully boot (service LED, ssh)? was the cable plugged in BEFORE
  power-on (the v18 fix is just a 10s poll, not magic)?
  same TV/port/cable as when it was OK?
- Tool: onbox/hdmi-report (md5 299de7ae31d70e24022985ab4cb6dff5,
  sh -n PASS, ASCII-only) — 1-shot: meta, systemd state, drm sysfs,
  connector status/modes/edid hexdump, HPD irq 2 samples, dmesg
  drm|hdmi|vop|inno|lima|fbcon + rknand + ext4, /proc/fb, vtcon
  bind, /dev/dri, Xorg/DM state, self-md5 to guard against wrong paste.
  Run: sh /usr/local/sbin/hdmi-report > /tmp/hdmi-report.txt 2>&1
- Tools audit: v-hdmi-check1..4.sh (kernel/config/bootimg/resource
  parser). Lesson: the hand-written bootimg parser got the offsets wrong (magic 8B
  then kernel_size@8 … pagesize@36, cmdline@64 — not the field
  layout I originally guessed).

## 91. Round 86 — HDMI debug: direct UART/SSH, RCA of the HPD-flap restore

- New channel: CH341 @COM23, tools/uart-console.ps1 (probe/send/capture);
  then SSH root@<box-ip> pass=1234 via the SSH_ASKPASS trick
  (SSH_ASKPASS_REQUIRE=force) — scp worked, more efficient than UART.
- On-box observations (kernel #26): HPD OK, EDID 256B standard (monitor =
  HKC H27T22S 27" 2K144, id 4d 67 a8 27 — SAME device as in §48),
  DRM connector enabled/dpms On, VOP ACTIVE mode 1920x1080p120
  dclk 297MHz, plane win1-0 ACTIVE but buf addr 0x00000000 → black.
- Red herrings ruled out one by one: (1) V18HPD still present, DRM =y; (2) fb0 "disappearing"
  was an ARTIFACT — CONFIG_FB_DEVICE=n (even during the HDMI-OK era, work/kernel-out/
  kernel.config) → there was never a /dev/fb0, /proc/fb, or sysfs fb0;
  fbcon still uses the internal fb_info; (3) DTB: hdmi pinctrl phandles
  0x67/0x68/0x69 SAME as baseline; reserved-memory (drm-logo@0
  reg=<0 0> → warning "failed to reserve") SAME as baseline — the warning
  has existed since the HDMI-OK era, not a regression; (4) source re-extract
  06/09 08:52 BUT v18.1 HDMI-OK was also built on this tree
  (planb-v18.sh 07/09) → no patch was lost between v18 and #26;
  kernel delta is only dwmac + TASKSTATS + LEDS_TRIGGER_NETDEV.
- Mechanism proof: hpd-watch.sh — commit 1080p60 via modetest
  (595.021) → HPD irq +3 (6→9) → 250ms later something re-commits
  1080p120 (595.251); the exact pattern repeats at 839s. TMDS enable
  causes an HPD glitch → connector flap → fb_helper restores mode p120.
  p120 steady-state mode doesn't flap but plane addr 0 → black.
  modetest p60 also goes black because it gets overridden within <1s.
- monitor capability: EDID range 48-144Hz, max pclk 600MHz;
  1440p rejected by inno_hdmi (mode list cut off at 1080p — phy table
  297MHz max). Preferred EDID (DTD#0) = 2560x1440p60 CVT-RB.
- Action: parameter.txt.force (md5 3bccabd1392a9e340d26922b68bb4aeb,
  video=HDMI-A-1:1920x1080@60e) → user flashes @0x0. Reason to expect
  it works: the cmdline USERDEF mode beats every fb_helper restore; this is
  the mechanism that ran OK back in v16.x. If force-60 is still black → dig into inno_hdmi
  PHY debounce; if OK → settle on force-mode, consider a native patch later.
- Lessons: (a) /proc/fb + /sys/class/graphics/fb0 not existing
  does NOT mean fb was unregistered — 6.6 split out FB_DEVICE (chrdev/
  procfs/sysfs are opt-in); (b) ssh via SSH_ASKPASS_REQUIRE=force
  works for non-interactive password auth on Windows OpenSSH; (c)
  don't reboot the box yourself while rushing a removal — DRM unbind hits a vendor bug
  (debugfs cleanup oops) → box stuck at shutdown, requires a power-cycle.

## 92. Round 87 — force-mode VERIFIED on box, HDMI case closed

- User flashed parameter.txt.force @0x0 → TV shows the Armbian console
  at 1080p60. OFFICIAL FIX.
- On-box after flash (SSH): boot `Update mode to 1920x1080p60`
  @3.355s; then ONE flip back to p120 @96.9s (HPD event) — but
  the plane keeps a real framebuffer: summary `buf[0] addr: 0x007e9000,
  pitch 7680` → image still alive. Compare with the old black state:
  `addr: 0x00000000`. → Root mechanism: native boot enables the CRTC
  p120 BEFORE fbdev (show-logo path), fbdev never attaches an fb
  to the plane → scans addr 0 forever. Force `video=` so the fb attaches from the start,
  every later restore is harmless because the plane already has a real buffer.
- On-box cleanup: fb-detect.service disabled + removed
  (/usr/local/sbin/fb-detect.sh, /root/fbdetect.log), /tmp/*
  tools cleaned up. HPD irq 77 count 6 (the 10s background poll still not running —
  userland only watches sysfs).
- Final artifacts: parameter.txt.force (md5
  3bccabd1392a9e340d26922b68bb4aeb, sha256
  c0c82b3d6914a5b633ed20beef76cebf942ff400a6c81ef89c45d86b63f89196),
  added SHA256SUMS.txt. Guide Z.28 records the RCA + fingerprint debug
  (summary addr ≠ 0 = alive). Native rollback: parameter.txt
  ab7c5744… @0x0 (reproduces the black screen).
- Future options (not doing now): cap mode_valid
  inno_hdmi ≤165MHz so native boot won't pick p120, drop the
  video= token; and/or debounce HPD in the inno_hdmi ISR. Both need
  a kernel #27 rebuild.

## 93. Round 88 — kernel #27: cap inno mode_valid at 165MHz, clean native boot

- Patch (inno_hdmi.c.orig-v27 backup): mode_valid previously = MODE_OK
  unconditionally; now `mode->clock > 165000 → MODE_CLOCK_HIGH`.
  Basis: the RK3128 PHY table is only calibrated up to 165MHz (74250/
  165000) — above that inno_hdmi_phy_tx_power_on picks a junk
  entry (0x00/0x00). p120@297 and 1440p60@241.5 are now cut at the mode
  filter → EDID fallback = 1080p60 148.5MHz. The CONNECTOR's mode_valid
  filters on both the fbdev and atomic paths — it runs before
  VOP. This patch works regardless of which stage enables the CRTC.
- Build: (a) first attempt failed — missing cd /vol/kernel-src before make
  olddefconfig (with O= + -C: SRCTREE . is the current dir → no
  olddefconfig rule; lesson: with make O= ALWAYS cd into the src first);
  (b) zImage OK 6.6.89-rk3128+, zImage md5 185d999b4f517cf25e9abb
  766c713b67; (c) checking the object by grepping for a string is wrong (enums don't
  produce text) — correct: objdump/od looking for the const 165000 (88 84 02 00
  little-endian) → CAP PRESENT.
- Boot v27: 8abbb3cbd737cf4eb2957d189d735dd5 (sha256
  e35dee52…) — zImage #27 + old initrd + resource v23.2 (DTB
  b218d71d unchanged). SHA256SUMS.txt updated; archived
  boot-v27.img. Tools: planb-v27.sh, work/v27-verify.sh.
- Flash when the user is ready: boot.img @0xE000 + parameter.txt
  (native ab7c5744…) @0x0 — video= no longer needed. Expectation:
  Update mode to 1920x1080p60 right at boot, no p120 flip
  (no mode >165 left to restore), picture from the moment fbcon comes up.
- Source status settled after this round: the tree has 3 valid diffs
  (V18HPD, dwmac v24.4c, cap-165) — no more "lost patches".
- Rollback note: there is NO boot archive for v24.4c (only v24.3/v24.4b
  md5 5f61edcd/82c2e4e0 — not v24.4c f1e30989). To get #26 back:
  restore inno_hdmi.c.orig-v27 + run planb-v27.sh.

## 94. Round 89 — kernel #28: fbdev shadow buffer, fix the tearing console

- User confirmed #27 native OK but the picture is "torn and mushy"
  when moving. On-box measurements: aclk 297MHz, dclk 148.5MHz (BW sufficient),
  VOP IRQ 0/10s idle (vblank off when idle — normal), regs
  debugfs is a subdirectory (vop_dump/dump, calculated_dclk_rate=0).
- RCA: vendor fbdev has no shadow/no damage — sys ops draw straight
  into the GEM WC being scanned out by VOP → tearing + copyarea slow on WC.
  CONFIG_FB_DEFERRED_IO=y already present; the helper has damage_range/area +
  a generic deferred_io; EXPORT_SYMBOLs sufficient.
- Patch #28 (rockchip_drm_fbdev.c.orig-v28 backup): screen_buffer
  = vzalloc cached shadow; fb ops: fillrect/copyarea/imageblit wrap
  sys_* + damage_area; fb_write wraps fb_sys_write + damage_range;
  fb_dirty = blit clip → GEM (mutex helper->lock) + fb->funcs->
  dirty (rockchip has no .dirty — skip OK); fb_destroy =
  fb_deferred_io_cleanup + vfree + framebuffer_release; fb_release
  is a no-op; FBINFO_VIRTFB|READS_FAST; defio delay HZ/20;
  helper->fbdefio (field really exists @drm_fb_helper.h:207).
- 3 build errors on attempt 1: helper->shadow_buffer doesn't exist (moved to a local
  var); defio_write used before definition (forward decl);
  guard patch skipped the tail block because the detect string collided with a goto label —
  lesson: guard string-matching must detect the right block, not
  a neighboring string. Patches via pwsh heredoc get mangled by quoting → always use a .py file.
- Build OK: fbdev.o rebuilt 13:40:29; boot v28 md5
  86687c83060950fe363414b7286300e6 (sha256 4046ad41…); zImage
  bec235981475e78a1501b61c5a5eb9d9; archived boot-v28.img;
  SHA256SUMS updated. Flash 1 file @0xE000, keep the native parameter.
- Expectation: console tearing gone. If it persists under heavy motion →
  try parameter.txt.force720 (1280x720@60e, already prepared) to discriminate
  BW-vs-sync.




- §95 Diagnosing #28 after the "still torn" report: cmdline force720 WAS picked up
  at boot (Update 1280x720p60 @3.2s) but Xorg (lightdm, vt7,
  -novtswitch) took over the console ~13.7s in and then set 1080p60 itself @80.9s
  (dmesg "Update mode to 1920x1080p60" was X itself, NOT a
  kernel revert). Conclusion: user tearing is at the X desktop (llvmpipe,
  no vsync), NOT fbcon #28.
- §96 Diagnostic trap: /sys/class/tty/tty0/active = VT foreground
  (tty7=X) — "frozen console" was just X holding the VT; the vc text buffer
  (vcs1) still accepted writes, fb render blocked by KD_GRAPHICS. VT_ACTIVATE
  1 (+0x5606, /dev/tty0) returns the console to tty1. ftrace filtered
  function_graph RUNS fine on this kernel (sanity-checked
  schedule hits), 0 calls = genuinely not called.
- §97 Direct demo: scroll 3×750 lines → user confirmed "smooth
  scrolling, no tearing" (#28 OK). Flood 3×2500 lines + ftrace measured
  rockchip_fbdev_dirty: 17688 copies, p90 6.7µs, max 13.1µs,
  0 instances >16.7ms — fbcon draws per-line bitblit + per-line damage,
  never overflowing a frame. #28 officially PAID.
- §98 Xorg 1.21.1.7 modesetting: installed
  /etc/X11/xorg.conf.d/60-tearfree-720p.conf (TearFree true +
  Monitor HDMI-A-1 PreferredMode 1280x720; log confirmed
  "initial mode 1280x720" + "Damage tracking initialized";
  the "Option TearFree is not used" warning is cosmetic — TF defaults
  on in 21.1). User result: mouse still torn + low fps
  (llvmpipe on A7). User changed their mind: drop the desktop.
- §99 Final: systemctl disable lightdm (Removed
  display-manager.service) + stop; Xorg 0 processes; VT_ACTIVATE 1
  → fg tty1; mode restored to 1280x720p60 (one 720p120 blip when X
  exited, then fbcon restored from the cmdline video= — correct). Final
  configuration: console-only on the TV @720p60, SSH as the main entry. No
  new kernel needed; boot.img stays v28; parameter stays native
  (cmdline video=720e currently active, working correctly).

- §100 PACK A 1-FILE UPDATE.IMG LIKE ANDROID STOCK. User asked
  to merge the small flash files into a single .img file like stock. Correct flow =
  the Firefly wiki "Customize Firmware": afptool -pack (needs a file named
  exactly `parameter` in the pack dir + a package-file "name<TAB>
  path") → img_maker wraps RKFW (header 0x66: magic, ver=6.6.89,
  chip "A213", loader@0x66 len 0x1d94e, image@0x1d9b4, md5 32 hex
  at the end). Tool mirror dayongxie/rk2918_tools (TeeFirefly 404) — 2
  patches: line buffer 512→4096 (stock CMDLINE 628 chars > fgets 511 →
  "File read failed!"), chiptype 0x50→"A213" (0x33313241) mirroring
  stock. Stock roundtrip: repack matches byte-for-byte minus header/padding
  (12.288B) — payload identical, tool trustworthy. The old unpack tool
  only accepts a RELATIVE dst (create_dir cuts at the first '/' of
  an absolute path → mkdir("") fails, silently). Product:
  output/planb-stock-uboot/update_armbian_v28.img 1.174.931.928B
  md5 5f1e173657cb41d0bd509d2bac45c32c, SHA256 56e5bde4…; RKFW →
  stock MiniLoader V2.25 (bit-perfect) → RKAF 11 parts: parameter
  (force720 + explicit root 0x300000 — avoids nand_size=0 when
  the flasher processes root, rootfs 1.08GB md5 aa1a26fb…), stock uboot,
  zeroed misc, baseparamer 720P, resource v23.2, boot v28, root,
  no-op scripts (native layout has no kernel/recovery/backup →
  the stock update-script is dangerous: write_image KERNEL:/SYSTEM: +
  write_loader into MISC). Two-layer verify: python (md5 trailer,
  loader, AFP extract) + afptool -unpack (each part's md5 matches
  the source: boot 86687c83…, resource b12893c9…, rootfs aa1a26fb…,
  uboot 0c9788a3…, misc addee4c5…, baseparamer 2d6b6a4e…;
  parameter IDENTICAL). Scripts: tools/build-update-img.sh,
  tools/verify-update-img.sh, tools/rkfw-verify.py,
  tools/bindiff.py, tools/rkaf-parts.py; binaries in docker
  /tmp/rk2918_tools (rebuildable from a host clone). Warning: box
  was offline at build time — rootfs 26.2 assumed live (not yet directly
  compared against /etc/os-release); RKDevTool real flash not yet tested (user does it).

- §101 CORRECTION: user flashed the §100 build → kernel panic `run-init:
  /sbin/init: No such file or directory` (fsck mount OK, ENOENT for
  every candidate init). RCA: packed the wrong `armbian_rootfs_26.2_xmio.img`
  (old checkpoint said "likely live" — wrong). 26.2 = the repack from EARLY 6-Sep,
  usrmerge BROKEN: `/bin`,`/sbin` are usr/* symlinks but `/lib` is a
  REAL directory containing only `modules` (timestamp 6-Sep) →
  `/sbin/init → /lib/systemd/systemd` dangling (and the dynamic loader
  `/lib/ld-linux-armhf.so.3` likewise). fsck panic UUID f62d9d2c…
  == dumpe2fs 26.2 → confirms the box mounted exactly the broken image. Production
  lineage: v23 → v23.2 (`657da568d2a31ae1676eda78a63091b9`, NOTES
  §80 "built CLEAN from v23") — `/lib` = symlink `usr/lib`, init chain
  resolves OK; and v23.2 does NOT enable lightdm (no display-manager
  .service, no graphical.target.wants — lightdm back then was a runtime
  install on the box) → flashing v23.2 = the correct console-only state.
  LESSON 2: afptool fread fails SILENTLY when the source file is Windows-
  locked (AV) — the first v23.2 build put the rootfs into the package at size=0 (padded
  0x0 in the part table) while still saying "Pack OK!" — the tool doesn't check
  ferror; discovered thanks to the part-table dump. Fix: docker cp the rootfs into
  the container fs + assert md5 `657da568…` BEFORE pack (the script now has
  the assert; /tmp/rootfs-v232.img kept in the container). Rebuild:
  `update_armbian_v28-v232.img` 1.174.931.928B md5
  `f3223b97b5a867f8fc2fe4249708812c` SHA256 284d09f2…; two-layer
  verify + init-chain debugfs directly on the file extracted from the package. The old
  `update_armbian_v28.img` (26.2) could not be deleted at the time (RKDevTool
  was holding the file) — marked BROKEN, don't flash it; delete when convenient.
  Big lesson: "likely live" in a checkpoint must be re-verified with
  evidence (md5 vs NOTES lineage) before it goes into an artifact.

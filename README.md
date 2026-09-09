# Armbian for the XMIO RK3128 TV box (VTIDC, NAND flash)

Custom **Armbian** build for the **RK3128** Android TV box (branded XMIO, stock
firmware `update_(VTIDC_XMIO_20160128_for_nandflash).img`). The stock Android
firmware runs fully on this box — display, USB and the SD card slot all work —
but the base Linux build (A26) came up with **no display and no USB host** on
the XMIO hardware. This project fixes that hardware bring-up and hardens the
build for long-term NAND use.

Base project: [A26 release by
@chieunhatnang-personal](https://github.com/chieunhatnang-personal/linux-kernel-6.6-rk3128-tvbox)
(kernel 6.6.89 + Armbian rootfs for RK3128 TV boxes). This fork adapts it to
the XMIO hardware and hardens it for long-term NAND use.

## Status

- **Kernel 6.6.89-rk3128+ (#28)** with fbdev shadow-buffer + damage blit —
  HDMI console is tear-free, ~0% CPU with the HDMI cable unplugged.
- **Rootfs v23.2** (production lineage) — console-only by design
  (no display manager); the box is used over SSH.
- **One-click `update_armbian_v28-v232.img`** in Android stock `RKAF` format —
  flash with RKDevTool like a stock firmware. See
  [docs/FLASH-GUIDE.md](docs/FLASH-GUIDE.md).

## What was fixed (vs the A26 base)

| Problem | Fix |
|---|---|
| No USB host power | Custom DTS `rk3128-xmio.dtb` — GPIO3_C4 VBUS hog (extracted from the real XMIO stock DTB) |
| Kernel silently dies after `Starting kernel…` | PSCI/SIP bring-up, timer/clocksource fixes, `clk_disable_unused` gating `sclk_timer0`, FTL GC race vs vendor-storage — see the research log |
| Extremely slow I/O (10–20 ms/page) | `usleep_range` quantum fix in the rk_nand driver (v17.2) |
| MAC address random every boot | MAC restored from vendor storage / label via DTB + U-Boot env (v23–v24.4) |
| Wrong `/proc/cpuinfo` (Hardware/Serial) | per-device values via DTB (v24.2) |
| NAND wear | RAM-only logging (v22), ext4 journal tuning |
| HDMI console tearing | fbdev shadow buffer + per-line damage blit (v28) |
| Inno panel driver accepts invalid modes | 165 MHz pixel-clock cap (v27) |

The full debugging story — every dead end and every measurement — is in
[NOTES.md](NOTES.md) and [docs/FLASH-GUIDE.md](docs/FLASH-GUIDE.md).

## Quick start (flash the box)

1. Download `update_armbian_v28-v232.img` from
   [Releases](../../releases) (or the plain files in `output/planb-stock-uboot/`).
2. Put the box into **Loader/MaskROM mode**, open **RKDevTool → Upgrade
   Firmware**, load the image, press **Upgrade**.
3. After boot: `ssh root@<box-ip>` (default password `1234`, change on first
   login). Console is 720p60 on HDMI; UART debug on UART2 @1500000.

Full instructions, UART bring-up, A/B DTB testing, rollback paths:
[docs/FLASH-GUIDE.md](docs/FLASH-GUIDE.md).

## Repository layout

```
docs/                 FLASH-GUIDE.md (flashing + research history),
                      BUILD.md (rebuild from scratch), RKAF-FORMAT.md (RKAF/RKFW notes)
tools/                build pipeline: Dockerfile, kernel build, rootfs repack,
                      SD image, update.img packer, RKAF/RKFW python tools
tools/patches/        the kernel/DTS patch scripts (v9 … v28), applied in order
tools/archive/        one-shot investigation scripts from the research log
repos/                vendored upstream sources (see "Sources" below)
output/               final artifacts (checksums in SHA256SUMS.txt)
  planb-stock-uboot/  current production flashables: boot.img, resource.img,
                      parameter.txt variants, stock uboot/loader, update.img
  dtb/                rk3128-xmio.dtb + 19 overlays
  kernel/             zImage + kernel.config
  debs/               linux-image / headers / libc-dev 6.6.89-rk3128-2
  nand-flash/         loader, uboot.img, trust.img, parameter.txt
NOTES.md              full research journal (sections §1–§101)
```

### Sources

- `kernel-source` **branch** — the complete patched kernel tree (upstream
  `chieunhatnang-personal/linux-kernel-6.6-rk3128-tvbox` @ `ee74d0bd` + the
  XMIO board DTS). Kept on a separate branch because it contains
  case-sensitive filenames that a Windows/NTFS working tree cannot hold;
  check it out on Linux/WSL (see [docs/BUILD.md](docs/BUILD.md)).
- `repos/u-boot-rk3128-tvbox/` — U-Boot 2017.09 BSP
  (`chieunhatnang-personal/u-boot-rk3128-tvbox` @ `218938c`), vendored in-tree.
- `repos/RK3128-Linux-SupportingScripts/` —
  (`chieunhatnang-personal/RK3128-Linux-SupportingScripts` @ `da323ac`),
  vendored in-tree.

Large files (`update_armbian_v28-v232.img` ~1.1 GB, `armbian_rootfs_v23.2_xmio.img`
~1.1 GB, `XMIO-bundle.tar.gz`, and the stock Android firmware
`update_(VTIDC_XMIO_20160128_for_nandflash).img` ~543 MB) are attached to the
[GitHub release](../../releases) instead of git.

## Rebuild from scratch

Docker-based cross build (Debian 12 + gcc-arm-10.3 toolchain):

```powershell
docker build -t rk3128-build tools
# kernel source: check out the kernel-source branch (Linux/WSL — see docs/BUILD.md)
git clone -b kernel-source https://github.com/realldz/rk3128-xmio-armbian repos/linux-kernel-6.6-rk3128-tvbox
# uboot + supporting scripts: already vendored in repos/, nothing to clone
docker run --rm --privileged -v rk3128-build-vol:/vol -v "${PWD}:/workspace" `
  rk3128-build bash /workspace/tools/rebuild-all.sh
```

Details, toolchain download, kernel #28 rebuild and update.img packing:
[docs/BUILD.md](docs/BUILD.md).

## Credits

- [@chieunhatnang-personal](https://github.com/chieunhatnang-personal) — kernel 6.6 port,
  SupportingScripts, original A26 release.
- [dayongxie/rk2918_tools](https://github.com/dayongxie/rk2918_tools) —
  afptool/img_maker (patched here for the 3128 chip tag and long mtdparts lines).
- [rkflashtool](https://github.com/linux-rockchip/rkflashtool) — vendored in
  `tools/rkflashtool-src/` (rkunpack).
- Rockchip stock bootloader binaries are redistributed unchanged as firmware
  payload (they belong to the original XMIO firmware).

## License

MIT — see [LICENSE](LICENSE). Kernel source and patches are GPL-2.0 as per
Linux; third-party tools keep their original licenses.

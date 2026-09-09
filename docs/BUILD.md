# Rebuilding everything from scratch

Everything in this repo was built inside a Docker container (Debian 12, cross
toolchain) on a Windows host. This document describes the full pipeline: toolchain
→ kernel → rootfs → boot chain → one-click `update.img`.

## 0. Prerequisites

- Docker Desktop (WSL2 backend), ~15 GB free space, internet access.
- The kernel source is **included in this repo** on the `kernel-source`
  branch (a single case-correct root commit vendored from
  `chieunhatnang-personal/linux-kernel-6.6-rk3128-tvbox` @ `ee74d0bd` +
  the XMIO board DTS). Check it out into `repos/linux-kernel-6.6-rk3128-tvbox`
  — on **Linux/WSL** (the tree contains filenames that differ only in case,
  e.g. `xt_CONNMARK.h` vs `xt_connmark.h`; a Windows/NTFS checkout loses
  them). Inside WSL:

  ```bash
  git clone -b kernel-source https://github.com/realldz/rk3128-xmio-armbian repos/linux-kernel-6.6-rk3128-tvbox
  ```

  or, from an existing clone of this repo: `git worktree add repos/linux-kernel-6.6-rk3128-tvbox kernel-source`
  (needs the Linux filesystem — use WSL even when the repo itself sits on the
  Windows drive via `\\wsl$`).

  Upstream for reference: `chieunhatnang-personal/linux-kernel-6.6-rk3128-tvbox`.
- `repos/u-boot-rk3128-tvbox/` (U-Boot 2017.09 BSP @ `218938c`) and
  `repos/RK3128-Linux-SupportingScripts/` (@ `da323ac`) are **vendored
  directly in this repo** — no clone needed.

- Cross toolchain `gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf`
  — download from ARM and place it as `tools/toolchain/gcc-arm-10.3.tar.xz`
  (the tarball is not stored in git; ~99 MB).

## 1. Build image

```powershell
docker build -t rk3128-build tools
```

`tools/Dockerfile` installs: `gcc-arm-10.3` runtime deps, `dtc`, `u-boot-tools`
(mkimage), `e2fsprogs` (debugfs), `losetup` support, `python3`, `xz`.

## 2. Full pipeline (Plan A — SD image + NAND rootfs)

```powershell
docker run --rm --privileged -v rk3128-build-vol:/vol -v "${PWD}:/workspace" `
  rk3128-build bash /workspace/tools/rebuild-all.sh
```

`tools/rebuild-all.sh` runs six stages: toolchain unpack → kernel source export
(`git archive`, LF-forced — see the NTFS note below) → kernel + deb build
(`tools/build_kernel.sh`) → rootfs repack (`tools/repack-rootfs.sh`) → baseline
DTB + SD image (`tools/make-sd-image.sh`) → embed fallback DTB + `xmio-collect`
+ patched boot.scr → checksums.

**NTFS case-collision warning.** The kernel tree contains files that collide on
case-insensitive filesystems (`xt_CONNMARK.h` vs `xt_connmark.h`, `aux.c`, …).
Never extract the kernel source directly onto the Windows drive; `rebuild-all.sh`
works in a Linux volume (`rk3128-build-vol`) and pipes the source through
`git archive`.

## 3. Kernel #28 (current production kernel)

The production boot chain is **Plan B**: Android stock flow — stock MiniLoader
V2.25 + stock U-Boot 2014 + Android-style `boot.img` + `resource.img` (DTB) +
Armbian rootfs. The custom-uboot arc (v1–v5) was abandoned; see NOTES §Z.20–Z.26.

To rebuild kernel #28 (fbdev shadow buffer + damage blit):

1. Patch the kernel source (run inside the container, scripts in
   `tools/patches/`, in this order):

   ```bash
   python3 /workspace/tools/patches/v28-patch.py
   python3 /workspace/tools/patches/v28-patch2.py
   python3 /workspace/tools/patches/v28-fix-unused.py
   ```

   (`v28-patch.py` adds the fbdev shadow buffer + per-line damage blit in
   `drivers/gpu/drm/rockchip/rockchip_drm_fbdev.c` — this is what kills console
   tearing; the others are small cleanups.)

2. Build zImage and repack `boot.img` with `tools/planb-v28.sh`:

   ```bash
   mkbootimg --kernel <zImage> \
     --ramdisk  output/planb-stock-uboot/initrd.img.gz \
     --second   output/planb-stock-uboot/resource.img \
     --base 0x60000000 --kernel_offset 0x00408000 \
     --ramdisk_offset 0x02000000 --second_offset 0x00F00000 \
     --tags_offset 0x00088000 --pagesize 16384 \
     --cmdline "" --output output/planb-stock-uboot/boot.img
   ```

   (`resource.img` = DTB wrapped by Rockchip resource format, built with
   `tools/pack_resource.py` from `output/planb-stock-uboot/rk3128-xmio-planb.dtb`.)

3. Verify the boot image RAM layout (the script asserts kernel/ramdisk/second
   regions do not overlap — `pagesize 16384` is mandatory, stock U-Boot expects
   it).

## 4. Rootfs v23.2

The production rootfs (`armbian_rootfs_v23.2_xmio.img`, md5
`657da568d2a31ae1676eda78a63091b9`) descends from the A26 release rootfs through
the incremental rootfs scripts in `tools/archive/` (`v22-rootfs.sh`,
`v23.*-rootfs*`, `v24.4-rootfs.sh`, …). Key properties:

- ext4, UUID and size matching `parameter.txt` (`root` partition, 1.5 GB with
  explicit size in the update.img parameter).
- **usrmerge intact**: `/bin`, `/sbin`, `/lib` are symlinks into `usr/*`;
  `/sbin/init → /lib/systemd/systemd` must resolve (a broken usrmerge causes
  `run-init: /sbin/init: No such file or directory` panic at boot — this was a
  real production incident, see NOTES §101).
- RAM-only logging (`log2ram`-style) to protect NAND.
- No display manager — console-only.

Inspect a rootfs image without mounting (works on the host):

```bash
debugfs -R "stat /sbin/init" armbian_rootfs_v23.2_xmio.img
debugfs -R "ls -l /sbin" armbian_rootfs_v23.2_xmio.img
```

## 5. One-click update.img (Android stock format)

`tools/build-update-img.sh` packs the flashable `RKFW` image exactly like a
stock Rockchip firmware:

1. Stage a pack dir: stock MiniLoader V2.25, stock `uboot.img`, zeroed
   `misc.img`, `baseparamer-720P.img`, production `resource.img` + `boot.img`,
   rootfs, no-op update/recover scripts, `package-file`.
2. `parameter` = `parameter.txt.force720` with the root partition size changed
   from `-@` (auto) to an explicit `0x00300000@0x00017000(root)` — the flasher
   mishandles `-@` (parses to 0).
3. `afptool -pack` → `img_maker` (RKFW wrap).

The `afptool`/`img_maker` binaries come from
[dayongxie/rk2918_tools](https://github.com/dayongxie/rk2918_tools) with three
patches applied (see [RKAF-FORMAT.md](RKAF-FORMAT.md) for the format and why):

- `char line[512]` → `char line[4096]` (stock XMIO mtdparts line is 628 chars;
  the 512-byte buffer truncated it and packing failed with "File read failed!").
- chip type `0x50` → `0x33313241` (`"A213"` little-endian) to match the stock
  3128 firmware header.
- Pack from a container-local copy of the rootfs with an **md5 assert** before
  packing: `afptool`'s `fread` fails silently on a Windows-locked file and still
  prints `Pack OK!` with a zero-size partition.

## 6. Verification

```bash
python3 tools/rkfw-verify.py update_armbian_v28-v232.img   # header + md5 trailer + extract
python3 tools/rkaf-parts.py update_armbian_v28-v232.img    # part table dump
sha256sum -c output/planb-stock-uboot/SHA256SUMS.txt
```

Cross-checks worth doing after a rebuild: loader bytes identical to stock
(`28ea9019…`), every extracted component md5 equals its source, parameter
CMDLINE identical to the hand-edited `parameter.txt.force720`, and the init
chain resolves inside the packed rootfs (`/sbin/init → /lib/systemd/systemd`).

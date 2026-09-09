# tools/

## Pipeline (the scripts that produce the release artifacts)

| Script | Purpose |
|---|---|
| `Dockerfile` | Build environment: Debian 12 + cross toolchain + dtc/mkimage/debugfs |
| `rebuild-all.sh` | Full Plan-A pipeline: toolchain → kernel → rootfs repack → SD image → checksums |
| `build_kernel.sh` | Kernel build wrapper (runs inside the container; patches `TOOLCHAIN_DIR`) |
| `repack-rootfs.sh` | Repack the A26 base rootfs with the new kernel deb (NAND layout) |
| `make-sd-image.sh` | Build the 2 GB SD-card image (boot chain + rootfs) |
| `planb-v28.sh` | Plan-B kernel #28 build + `boot.img` repack (mkbootimg + RAM-layout assert) |
| `build-update-img.sh` | Pack the one-click `update_armbian_v28-v232.img` (afptool + img_maker) |
| `xmio-collect.sh` | On-box diagnostic report collector (embedded into the rootfs) |
| `acceptance.sh` | One-command acceptance suite (30 checks) |

## Format tools (Python)

| Script | Purpose |
|---|---|
| `rkfw-verify.py` | Parse/verify an RKFW image: header fields, md5 trailer, extract loader + RKAF |
| `rkaf-parts.py` | Dump the RKAF partition table (name / file / pos / nand_addr / sizes) |
| `rkaf-parse.py` | Alternative RKAF parser |
| `pack_resource.py` | Wrap a DTB into Rockchip `resource.img` format |
| `extract_dtb.py` | Extract DTBs from a boot.img / resource.img |
| `analyze-rkimage.ps1` | Quick Windows-side structure dump |
| `uart-console.ps1` | Serial console helper for Windows |

## Forensics (debugfs, no mounting needed)

`check-rootfs-symlinks.sh`, `check-init-chain.sh`, `check-lib-dirs.sh` — verify
the usrmerge state and `/sbin/init` chain of an ext4 rootfs image. See
`docs/BUILD.md` §4 for why these exist (the §101 usrmerge panic).

## On-box binaries

`xmio-led.c` (+ prebuilt `xmio-led-arm`) — status LED daemon;
`v24-vendor-mac.c` — vendor-storage MAC reader/writer source.

## Subdirectories

- `patches/` — the 27 kernel/DTS patch scripts (v9 → v28), applied in version
  order; each one documents its target files in its header.
- `archive/` — one-shot investigation/diagnostic scripts from the research log
  (NOTES.md). Kept for reference; not part of the pipeline.
- `boot-patch/` — patched `boot.cmd`/`boot.scr` with the `xmio_fdt_override`
  recovery hook.
- `rkflashtool-src/` — vendored rkflashtool sources, pinned to upstream
  commit `fc2181c5` (github.com/brandonmwong/rkflashtool) (`rkunpack` is built
  from here; see `bin/`).
- `toolchain/` — cross toolchain tarball (not in git; download link in
  `docs/BUILD.md`).

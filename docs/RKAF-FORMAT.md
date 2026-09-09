# Rockchip RKAF / RKFW firmware format (as used on RK3128 XMIO)

Notes reverse-engineered while packing a custom one-click firmware
(`update_armbian_v28-v232.img`) to match the stock Android update image byte
layout. Verified against the stock firmware
`update_(VTIDC_XMIO_20160128_for_nandflash).img` (569,375,192 bytes).

Companion tools in this repo: `tools/rkfw-verify.py`, `tools/rkaf-parts.py`,
`tools/build-update-img.sh`.

## RKFW container (outer)

Header is 0x66 bytes, followed by the bootloader, the RKAF image, and a plain
ASCII md5 of everything before it:

| Offset | Size | Field | Stock XMIO value |
|---|---|---|---|
| 0x00 | 4 | magic `"RKFW"` | `RKFW` |
| 0x04 | 2 | head_len | 0x66 |
| 0x06 | 4 | version | 1 |
| 0x0A | 4 | code (merge?) | 0 |
| 0x0E | 7 | date (u16 year LE + 5 bytes) | 2016-01-28 |
| 0x15 | 4 | chip | `0x33313241` = `"A213"` LE = "312A" reversed |
| 0x19 | 4 | loader_offset | 0x66 |
| 0x1D | 4 | loader_length | 121,166 (MiniLoader V2.25) |
| 0x21 | 4 | image_offset | 0x66 + loader_length |
| 0x25 | 4 | image_length | rest minus 32 |
| EOF | 32 | md5 (32 ASCII hex chars) | — |

Stock total: `0x66 + 0x1D94E + 0x21EE2004 + 32 = 569,375,192`.

The chip field matters: the `img_maker` from the `dayongxie/rk2918_tools`
mirror writes `0x50` by default; RKDevTool for RK3128 expects `0x33313241`
(`"A213"`). We patched `img_maker.c` accordingly.

## RKAF partition image (inner)

The blob at `image_offset` starts with a 2048-byte header:

| Offset | Size | Field |
|---|---|---|
| 0x00 | 4 | magic `"RKAF"` |
| 0x04 | 4 | header.length (end of part table, start of data) |
| 0x08 | 34 | model (`RK3128`, NUL-padded) |
| 0x2A | 30 | id |
| 0x48 | 56 | manufacturer |
| 0x84 | 4 | version u32, packed `a<<24|b<<16|c` |
| 0x88 | 4 | num_parts (u32) |
| 0x8C | 16×112 | part entries |

Each 112-byte part entry:

| Offset | Size | Field |
|---|---|---|
| 0x00 | 32 | name (NUL-padded, must match the mtdparts name in `parameter`) |
| 0x20 | 60 | filename |
| 0x5C | 4 | nand_size (u32, NAND pages) |
| 0x60 | 4 | pos (offset of this blob inside the RKAF, 2048-aligned) |
| 0x64 | 4 | nand_addr (flash offset in pages; `0xFFFFFFFF` = not flashed, e.g. bootloader) |
| 0x68 | 4 | padded_size (u32) |
| 0x6C | 4 | size (u32) |

After the last blob there is a trailing 4-byte CRC over the whole image at
offset `header.length + total data`. The `parameter` entry is not stored raw:
it is wrapped in `PARM` format (magic `"PARM"` + u32 length + RKCRC32 of the
parameter text).

## afptool / img_maker quirks (all hit in practice)

1. **512-byte line buffer.** `afptool -pack` reads the `parameter` file with
   `fgets` into `char line[512]`. The stock XMIO mtdparts line is **628
   characters**, so packing failed with a confusing `File read failed!`.
   Patched to `char line[4096]` (2 occurrences in `afptool.c`).
2. **Silent `fread` failure.** If the input file is locked (Windows AV scan),
   `fopen` succeeds but `fread` returns 0 — `afptool` records a zero-size
   partition and still prints `Pack OK!`. Always assert the input md5 before
   packing (our `build-update-img.sh` does), and pack from a container-local
   copy of the file.
3. **`-@` auto size.** `0x00017000@...` partitions with `-@` (grow-to-fit)
   parse as `strtol("@…") = 0` → `nand_size = 0`. Use explicit sizes:
   `0x00300000@0x00017000(root)`.
4. **`-unpack` destination must be relative.** `create_dir()` stops at the
   first `/`, so absolute paths silently create nothing ("Can't create
   directory: " with an empty name). `cd` somewhere and pass a relative path.
5. **Chip tag.** See RKFW header above — `0x50` vs `0x33313241`.

## Part table of the production image

`update_armbian_v28-v232.img` (11 parts, 1,174,931,928 bytes):

| # | name | file | pos | nand_addr | note |
|---|---|---|---|---|---|
| 0 | bootloader | MiniLoaderAll(L)_V2.25_ink.bin | 0x800 | 0xFFFFFFFF | not flashed by upgrade |
| 1 | parameter | parameter (PARM-wrapped force720, root 1.5 GB) | … | 0x0 | |
| 2 | uboot | uboot.img (stock 2014.10-r3) | 0x2000 | | |
| 3 | misc | misc.img (zeroed) | 0x4000 | | |
| 4 | baseparamer | baseparamer-720P.img | 0x6000 | | |
| 5 | resource | resource.img (DTB rk3128-xmio-planb) | 0x6800 | | |
| 6 | boot | boot.img (kernel #28 + initrd, pagesize 16384) | 0xE000 | | |
| 7 | root | armbian_rootfs_v23.2_xmio.img | 0x17000 | | 1.5 GB partition |
| 8–10 | update-script / recover-script / package-file | no-op | — | — | |

md5 `f3223b97b5a867f8fc2fe4249708812c`, sha256
`284d09f2085293d073658b7e60f2d81cee3a14c4e570dc1c0d3b617936f962e9`.

#!/usr/bin/env python3
"""v11-patch.py — RK NAND (rk_nand) diagnostics for the rootfs-mount hang.

Background: v10 boots to initramfs, but /dev/rknand_root never appears and
initramfs-tools waits forever (rootwait). CONFIG_RK_NAND=y is compiled in
(symbols verified in vmlinux), yet the boot log shows no rknand messages.
The driver has SILENT failure exits:
  - rknand_probe: boot_media==2 -> return -1 (no print)
  - rknand_dev_init: nandc0 NULL -> return -1 (no print)
This patch adds V11DIAG pr_warn at every stage so the UART log pinpoints
where the chain dies. Line-based patches (robust to whitespace/tabs).
Idempotent: skips a file when V11DIAG is already present in it.
"""
import io
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "/vol/kernel-src"


def load(path):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        return f.readlines()


def save(path, lines):
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.writelines(lines)


def find_one(lines, key, path):
    hits = [i for i, l in enumerate(lines) if key in l]
    if len(hits) != 1:
        raise SystemExit("FATAL: %s: key %r hits %d (expected 1)"
                         % (path, key, len(hits)))
    return hits[0]


def patch_file(path, steps):
    lines = load(path)
    content = "".join(lines)
    if "V11DIAG" in content:
        print("SKIP %s (V11DIAG already present)" % path)
        return
    for key, mode, new in steps:
        idx = find_one(lines, key, path)
        if mode == "after":
            lines[idx + 1:idx + 1] = new
        elif mode == "before":
            lines[idx:idx] = new
        elif mode == "replace_span":
            n_old, repl = new
            if key not in lines[idx]:
                raise SystemExit("FATAL: span head mismatch in %s" % path)
            lines[idx:idx + n_old] = repl
        else:
            raise SystemExit("FATAL: bad mode %r" % mode)
        print("OK   %s: %s" % (path.split("/")[-1], key.strip()[:58]))
    save(path, lines)


# ---------------- drivers/rk_nand/rk_nand_base.c ----------------
BASE = SRC + "/drivers/rk_nand/rk_nand_base.c"
patch_file(BASE, [
    # 1. probe enter (answers: did the platform probe run at all?)
    ("g_nand_device = &pdev->dev;", "after", [
        '\tpr_warn("V11DIAG: rknand probe enter id=%u\\n", id);\n',
    ]),
    # 2. IDB sysdata content (the silent boot_media==2 abort lives below this)
    ("memcpy(nand_idb_data, membase + 0x1000, 0x800);", "after", [
        '\t\tpr_warn("V11DIAG: idb magic 0x%08x boot_media_raw %d\\n",\n',
        '\t\t\t*(int *)(&nand_idb_data[0]),\n',
        '\t\t\t*(int *)(&nand_idb_data[8]));\n',
    ]),
    # 3. probe reached the end
    ("return dma_set_mask(g_nand_device, DMA_BIT_MASK(32));", "before", [
        '\tpr_warn("V11DIAG: rknand probe done\\n");\n',
    ]),
])

# ---------------- drivers/rk_nand/rk_nand_blk.c ----------------
BLK = SRC + "/drivers/rk_nand/rk_nand_blk.c"
patch_file(BLK, [
    # 4. NANDC reg base as seen by the block layer (set only by a good probe)
    ("rknand_get_reg_addr((unsigned long *)&nandc0, "
     "(unsigned long *)&nandc1);", "after", [
        '\tpr_warn("V11DIAG: nandc0 %px nandc1 %px\\n",\n',
        '\t\t(void *)nandc0, (void *)nandc1);\n',
    ]),
    # 5. make the silent nandc0-NULL exit loud
    ("if (!nandc0)", "replace_span", (2, [
        '\tif (!nandc0) {\n',
        '\t\tpr_warn("V11DIAG: nandc0 NULL - probe failed or never ran\\n");\n',
        '\t\treturn -1;\n',
        '\t}\n',
    ])),
    # 6. FTL blob init result + capacity
    ("rknand_apply_bad_nand_policy();", "before", [
        '\tpr_warn("V11DIAG: rk_ftl_init ok capacity %u sectors (%u MB)\\n",\n',
        '\t\trk_ftl_get_capacity(), rk_ftl_get_capacity() / 2048);\n',
    ]),
    # 7. block devices registered (parts>0 -> rknand_root should exist)
    ("rk_nand_dev_initialised = 1;", "before", [
        '\tpr_warn("V11DIAG: nand_blk_register ok parts=%d\\n", '
        'g_max_part_num);\n',
    ]),
])

print("V11_PATCH_OK")

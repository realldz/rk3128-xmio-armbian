#!/usr/bin/env python3
# v16-dts.py — xmio-planb-v9.dts -> v16.dts
#  1. ENABLE sdmmc (mmc@10214000): was status="disabled" -> TF slot dead.
#     broken-cd = polling card detect (no wiring assumptions).
#  2. DISABLE vendor codec nodes: mpp_rkvdec/iommu spam red lines because
#     the vendor mpp driver needs vendor-only clock/reset names that the
#     mainline-style DT does not carry. Video decode never worked here.
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    d = f.read()


def node_block(text, header):
    i = text.index(header)
    j = text.index("{", i)
    depth, k = 1, j + 1
    while depth:
        c = text[k]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        k += 1
    return i, k


# 1) sdmmc enable
hdr = "\tmmc@10214000 {"
i, k = node_block(d, hdr)
blk = d[i:k]
assert 'status = "disabled";' in blk, "sdmmc node not disabled?"
blk = blk.replace(
    'status = "disabled";',
    'status = "okay";\n'
    '\t\tbroken-cd;\n'
    '\t\tcap-sd-highspeed;\n'
    '\t\tcard-detect-delay = <200>;')
d = d[:i] + blk + d[k:]
print("OK   sdmmc: enabled + broken-cd polling detect")

# 2) vendor codec nodes off
CODECS = ["\thevc@10104000 {", "\tiommu@10104440 {",
          "\tvepu@10106000 {", "\tvdpu@10106400 {",
          "\tiommu@10106800 {", "\tiep@10108000 {"]
for hdr in CODECS:
    i, k = node_block(d, hdr)
    blk = d[i:k]
    if 'status = "okay";' in blk:
        blk = blk.replace('status = "okay";', 'status = "disabled";')
    elif 'status = ' not in blk:
        j = blk.index("{")
        blk = blk[:j + 1] + '\n\t\tstatus = "disabled";' + blk[j + 1:]
    d = d[:i] + blk + d[k:]
    print("OK   codec off:", hdr.strip().rstrip(" {"))

with open(dst, "w", encoding="utf-8") as f:
    f.write(d)
print("V16_DTS_OK ->", dst)

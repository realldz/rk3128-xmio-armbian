#!/usr/bin/env python3
# v23.3-uboot-mac.py — patch stock U-Boot default environment:
#   + ethaddr=B8:3D:4E:84:3D:A3   (label MAC, applied to FDT by
#     fdt_fixup_ethernet() on EVERY bootm => any future firmware
#     whose boot.img we don't control still gets the right MAC)
#   - bootdelay / preboot / verify (dropped: unused or defaulted)
#   keep bootcmd, baudrate, initrd_high untouched.
# The 1MB image carries two identical 512K mirrors; patch both.
import hashlib, sys

SRC = '/workspace/output/planb-stock-uboot/uboot-stock.img'
DST = '/workspace/output/planb-stock-uboot/uboot-planb-mac.img'
MAC = b'ethaddr=B8:3D:4E:84:3D:A3'   # 25 chars
d = bytearray(open(SRC, 'rb').read())

HALF = 0x80000
assert len(d) == 2 * HALF, f'unexpected size {len(d):#x}'
assert d[:HALF] == d[HALF:], 'mirrors differ - abort'

# locate env region in first half
assert d.find(b'bootcmd=bootrk') == 0x3b1ba, 'bootcmd not at expected offset'
REG_OFF, REG_END = 0x3b1c9, 0x3b212          # bootdelay..before ", \0" rodata
old = bytes(d[REG_OFF:REG_END])
assert old.startswith(b'bootdelay=0\x00'), f'unexpected env start {old[:16]!r}'
assert old.count(b'baudrate=115200\x00') == 1
assert old.count(b'initrd_high=0xffffffff=n\x00') == 1

new = MAC + b'\x00'
new += b'baudrate=115200\x00'
new += b'initrd_high=0xffffffff=n\x00'   # byte-exact stock entry (quirk '=' included)
new += b'\x00' * (REG_END - REG_OFF - len(new))   # terminator padding
assert len(new) == REG_END - REG_OFF

for base in (0, HALF):
    d[base + REG_OFF: base + REG_END] = new

open(DST, 'wb').write(bytes(d))

# verify
v = open(DST, 'rb').read()
assert v[:HALF] == v[HALF:], 'patched mirrors differ'
for base in (0, HALF):
    assert v[base + REG_OFF: base + REG_OFF + len(MAC)] == MAC
assert v.count(b'ethaddr=B8') == 2   # one per mirror
for base in (0, HALF):
    assert b'bootdelay=0' not in v[base + REG_OFF - 0x20: base + REG_END]
print('md5      ', hashlib.md5(v).hexdigest())
print('sha256   ', hashlib.sha256(v).hexdigest())
print('OK uboot-planb-mac.img')

#!/usr/bin/env python3
"""Dump RKAF part table (name, filename, nand_size, nand_addr, pos, padded, size)."""
import struct, sys

data = open(sys.argv[1], 'rb').read(2048)
assert data[0:4] == b'RKAF', data[0:4]
length = struct.unpack('<I', data[4:8])[0]
model = data[8:42].split(b'\x00')[0].decode()
pid = data[42:72].split(b'\x00')[0].decode()
mfg = data[72:128].split(b'\x00')[0].decode()
n = struct.unpack('<I', data[136:140])[0]
print(f"model={model} id={pid} mfg={mfg} length={length:#x} parts={n}")
print(f"{'name':14} {'filename':46} {'nand_size':>10} {'nand_addr':>10} {'pos':>10} {'padded':>10} {'size':>10}")
for i in range(n):
    o = 140 + i * 112
    name = data[o:o+32].split(b'\x00')[0].decode()
    fn = data[o+32:o+92].split(b'\x00')[0].decode()
    nand_size, pos, nand_addr, padded, size = struct.unpack('<IIIII', data[o+92:o+112])
    print(f"{name:14} {fn:46} {nand_size:#10x} {nand_addr:#10x} {pos:#10x} {padded:#10x} {size:#10x}")

#!/usr/bin/env python3
# v24.3-dts.py — status-led (xanh/đỏ): bỏ heartbeat, default-state on
# (xanh sáng cố định ngay từ led-core registration ~1-2s).
# io-led (vàng) giữ nguyên — netdev được arm bởi rootfs service.
import re, sys

P = '/workspace/work/xmio-planb-v23.dts'
src = open(P).read()

OLD = '''\t\tstatus-led {
\t\t\tlabel = "xmio:red-green:status";
\t\t\tlinux,default-trigger = "heartbeat";
\t\t\tgpios = <0x51 8 0x01>;
\t\t\tdefault-state = "off";
\t\t};'''
NEW = '''\t\tstatus-led {
\t\t\tlabel = "xmio:red-green:status";
\t\t\tgpios = <0x51 8 0x01>;
\t\t\tdefault-state = "on";
\t\t};'''

if NEW in src:
    print('already patched (idempotent)')
elif OLD in src:
    src = src.replace(OLD, NEW, 1)
    open(P, 'w').write(src)
    print('status-led: heartbeat -> default-on (default-state on)')
else:
    sys.exit('anchor not found - abort')

#!/usr/bin/env bash
exec > /workspace/work/v18.2-analysis2.log 2>&1
F=/workspace/output/armbian_rootfs_v15j_xmio.img
echo '=== full read-only fsck of v15j (must be clean) ==='
e2fsck -fn "$F" 2>&1 | tail -8
echo
echo '=== journal details ==='
dumpe2fs -h "$F" 2>/dev/null | grep -iE 'journal|Filesystem state|features' 
echo
echo '=== hash the artifact ==='
sha256sum "$F"
md5sum "$F"
echo
echo '=== size / fit check vs flash window ==='
ls -la "$F"
python3 -c "
sectors = (1157545984 + 511) // 512
print('sectors needed:', sectors)
print('flash window: 0x17000 to end of 4GB (0xE00000 sectors*512=3.75GB) -> fits:', sectors < 3900000)
"

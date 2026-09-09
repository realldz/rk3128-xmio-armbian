#!/usr/bin/env bash
exec > /workspace/work/bundle.log 2>&1
set -e
cd /workspace
rm -f output/XMIO-bundle.tar.gz
tar -czf output/XMIO-bundle.tar.gz \
  -C output debs dtb kernel nand-flash planb-stock-uboot SHA256SUMS.txt \
  -C /workspace docs/FLASH-GUIDE.md NOTES.md README.md tools/boot-patch
tar -tzf output/XMIO-bundle.tar.gz | wc -l
ls -l output/XMIO-bundle.tar.gz
echo BUNDLE_OK

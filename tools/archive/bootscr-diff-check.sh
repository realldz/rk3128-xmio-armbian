#!/usr/bin/env bash
# Compare original vs patched boot.scr script DATA (legacy header is 72 bytes,
# not 64: 64-byte base header + 8-byte size extension before the data block).
cd /workspace/work
tail -c +73 boot.scr.orig > data-orig.txt
tail -c +73 boot.scr-xmio > data-new.txt
tail -c +73 boot.scr.orig | od -c | head -2
stat -c 'orig data: %s' data-orig.txt
stat -c 'new  data: %s' data-new.txt
diff --strip-trailing-cr data-orig.txt data-new.txt; echo "DIFF_EXIT=$?"
echo "=== first line of true data ==="
head -1 data-orig.txt

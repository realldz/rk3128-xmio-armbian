#!/usr/bin/env bash
for f in /workspace/tools/*.sh; do
  if bash -n "$f" 2>/dev/null; then echo "OK   $(basename "$f")"; else echo "FAIL $(basename "$f")"; fi
done
echo "=== xmio-collect structure check ==="
bash -n /workspace/tools/xmio-collect.sh && echo "xmio-collect syntax OK"
grep -c '2>/dev/null' /workspace/tools/xmio-collect.sh

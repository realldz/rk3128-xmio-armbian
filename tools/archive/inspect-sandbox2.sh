#!/usr/bin/env bash
echo "=== which file fails in common/ ==="
grep -B3 'common/.*Error' /workspace/work/sandbox-build3.log | head -10
grep -E 'CC      (common|cmd)/' /workspace/work/sandbox-build3.log | tail -5
echo "=== fatal errors in log ==="
grep 'fatal error' /workspace/work/sandbox-build3.log | sort -u
echo "=== current SDL/SCMI config after olddefconfig ==="
grep -E 'SDL|SCMI' /vol/uboot-sb-build/.config
echo "=== sdl.c compiled this run? ==="
grep -c 'sdl.o' /workspace/work/sandbox-build3.log

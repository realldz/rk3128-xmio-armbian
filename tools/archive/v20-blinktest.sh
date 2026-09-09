#!/usr/bin/env bash
cd /workspace/tools
touch /tmp/st /tmp/yl
export XLED_STATUS=/tmp/st XLED_YELLOW=/tmp/yl XLED_TRIG=/dev/null
LIB=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/arm-none-linux-gnueabihf/libc
timeout 6 qemu-arm-static -L "$LIB" ./xmio-led-arm &
PID=$!
for i in $(seq 1 12); do
  s=$(cat /tmp/st 2>/dev/null); y=$(cat /tmp/yl 2>/dev/null)
  echo -n "${s:-?},${y:-?} "
  sleep 0.4
done
echo
echo BLINK-TEST-DONE
wait $PID 2>/dev/null
echo "daemon exited: $?"

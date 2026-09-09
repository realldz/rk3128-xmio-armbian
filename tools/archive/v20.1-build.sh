#!/usr/bin/env bash
set -euo pipefail
TC=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-gcc
LIB=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/arm-none-linux-gnueabihf/libc
cd /workspace/tools
$TC -Os -Wall -o xmio-led-arm xmio-led.c && echo BUILD-OK
/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-strip xmio-led-arm
ls -la xmio-led-arm
md5sum xmio-led-arm
# --- gateway parser sanity: dump what the parser reads from container /proc ---
cat > /tmp/gwtest.c <<'EOF'
#include <stdio.h>
#include <string.h>
#include <arpa/inet.h>
int main(void){
  FILE *f=fopen("/proc/net/route","r"); char line[256]; char ifn[32]; unsigned dest,g;
  if(!f){printf("no /proc/net/route\n");return 1;}
  while(fgets(line,sizeof line,f)){
    if(sscanf(line,"%31s %x %x",ifn,&dest,&g)==3 && dest==0 && g!=0 && strcmp(ifn,"lo")){
      unsigned char b[4]={g&0xff,(g>>8)&0xff,(g>>16)&0xff,(g>>24)&0xff};
      printf("hex=%08X parsed=%u.%u.%u.%u\n",g,b[0],b[1],b[2],b[3]);
      fclose(f); return 0;
    }
  }
  printf("no default route in container\n"); fclose(f); return 0;
}
EOF
gcc -o /tmp/gwtest /tmp/gwtest.c && /tmp/gwtest
# --- qemu run: container has eth0 up; expect ping to gw and possibly GREEN ---
touch /tmp/st /tmp/yl
rm -f /tmp/xmio-led.log
export XLED_STATUS=/tmp/st XLED_YELLOW=/tmp/yl XLED_TRIG=/dev/null
timeout 4 qemu-arm-static -L "$LIB" ./xmio-led-arm || true
echo '--- /tmp/xmio-led.log ---'
cat /tmp/xmio-led.log || echo NO-LOG
echo '--- final LED values ---'
echo "status=$(cat /tmp/st) yellow=$(cat /tmp/yl)"

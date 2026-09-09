# Flash & test guide for Armbian on the XMIO RK3128 box

> This build is based on chieunhatnang-personal's A26 (Armbian 26.02 rootfs, kernel 6.6.89-rk3128+)
> with a **custom DTS rk3128-xmio.dtb** adapted from the box's stock Android DTB
> (extracted from the `VTIDC_XMIO_20160128_for_nandflash` firmware).

## A. Fastest way to check "is the kernel running yet": UART debug

You already have a USB-TTL adapter. On the RK3128, the debug UART can be on UART1 or UART2 (depending on the board).
**This image is configured to output kernel logs to UART1, UART2, AND HDMI at the same time** (115200 8N1) —
plug the USB-TTL into whichever pads and you'll see kernel logs. Note: **the U-Boot banner is printed on UART1 only**
(hardcoded in the A26 U-Boot), so if you see kernel logs on UART2, the U-Boot phase will be silent —
that's normal. GND is the supply negative; TX/RX are usually two pads scattered across the board (usually
near the USB port or next to the IR receiver).

- USB-TTL TX → box RX, RX → box TX, GND ↔ GND (do NOT connect 5V/3V3 to the box).
- Open a terminal (PuTTY/MobaXterm) at 115200 8N1.
- Power on the box → you must see U-Boot logs right away (U-Boot prints on UART1).

**Expected logs, stage by stage** (on a box that boots fine):
1. Power on → a few DDR/miniloader lines (may print on **UART2** instead of UART1 —
   Rockchip loaders usually default to UART2) — of the form `INFO:ddr` / `DDR Version ...`.
2. Next, the **U-Boot** banner on UART1: `U-Boot 2017.09-... (RK3128 >>)` and the 9s bootdelay countdown.
3. U-Boot loads the kernel → prints `Starting kernel ...` → kernel log (if the console is right).
   - You only get to step 2 and then it hangs: the kernel/DTB has a problem → send me the log.
   - Nothing at all on either UART: the BootROM can't read the loader → a flash problem.

If you see logs → capture them and post them into the conversation so I can analyze further.

## B. Flashing NAND via RKDevTool (preferred)

Use **RKDevTool v2.69**, which ships with the A26 build (already in `A26-release-20260430/`).

Files you need (in `output/nand-flash/`):
| File | Purpose |
|---|---|
| `rk3128_loader_v2.12.263.bin` | load via MaskROM (Loader tab) — same as the original A26 |
| `parameter.txt` | original A26 (uboot/trust/root layout) |
| `uboot.img`, `trust.img` | original A26 (unchanged) |
| `output/armbian_rootfs_26.2_xmio.img` | **new rootfs** (XMIO kernel + DTB + overlays) |

Procedure (same as the author's guide; only the rootfs file is swapped):
1. Get the box into **MaskROM/Loader mode**: hold the reset button while plugging the USB OTG into the PC
   (or hold recovery, then reset). RKDevTool reports "Found One MASKROM Device".
2. Tab **升级固件/Download Image**: load `rk3128_loader_v2.12.263.bin` first (EraseFlash + Download).
3. Tab **Download Image** (load each file at its 512B-sector address):
   - `parameter.txt` → address `0x00000000`
   - `uboot.img`   → `0x00002000`
   - `trust.img`   → `0x00004000`
   - rootfs image  → `0x00006000` (the address of the `root` partition)
   > Remember to tick each row, then click "Download". The correct address = the address in `parameter.txt`.
4. Reboot the box.

## C. SD card (if you want a quick test without touching NAND)

The XMIO's SD card slot works (it runs fine under the stock Android firmware);
it is simply not part of the native NAND boot layout. An SD image can be built
with `tools/make-sd-image.sh` (`output/xmio-sd-2g.img` — bootloader at sectors
64/16384/24576 + an ext4 partition holding the entire XMIO rootfs; not shipped
in the release, build it yourself). Flash it with **balenaEtcher/Rufus (Windows)**:
1. Pick the `xmio-sd-2g.img` file → pick the TF card → Flash.
2. Insert the card into the box and power it on. U-Boot (on NAND) will boot the SD ahead of NAND.
   > The A26 U-Boot's boot order is USB → SD → NAND; if the NAND already has the original A26 flashed, the SD card
   > only wins if U-Boot can see and parse the ext4 partition on the card.

## D. DTB A/B testing — root-causing problems

The rootfs ships with **2 DTBs** in `/boot/dtb/`:
- `rk3128-xmio.dtb` (default) — the XMIO DTB: USB host VBUS hog GPIO3_C4, ESP8089 WiFi, uart2.
- `rk3128-linux.dtb` — the author's original baseline (known to boot on his own board).

If you boot with the XMIO DTB, can SSH over LAN, but USB/PCI misbehaves → swap DTBs to cross-test
whether the fault is the new DTB or the kernel:
```
# qua SSH:
sudo sed -i 's/^fdtfile=.*/fdtfile=rk3128-linux.dtb/' /boot/armbianEnv.txt && sudo reboot
# back to the XMIO DTB:
sudo sed -i 's/^fdtfile=.*/fdtfile=rk3128-xmio.dtb/' /boot/armbianEnv.txt && sudo reboot
```

**UART recovery trick (no file editing needed)**: get to the U-Boot prompt (`RK3128 >>` — press any key
within the first 9s). The boot script ships with an XMIO hook — variables set at the prompt survive
the `env import` of armbianEnv.txt:
```
setenv xmio_fdt_override rk3128-linux.dtb; boot      # force the baseline DTB once
setenv xmio_fdt_override rk3128-xmio.dtb; boot       # back to the XMIO DTB
setenv xmio_overrides "usb-otg-host uart1 dmc-disabled"; boot   # force a different overlay set
```
(For a permanent change, edit `/boot/armbianEnv.txt` over SSH as shown above.)

## E. Post-boot checklist

1. SSH over LAN: `ssh root@<ip-box>` password `1234` (the Armbian default, changed at first login).
2. Run `sudo xmio-collect` → it creates `/tmp/xmio-report.txt` containing all the diagnostic info
   (dmesg, USB, GPIO, DRM/HDMI, WiFi, cpufreq...) → post this file into the conversation.
3. USB: plug in a USB stick → `lsusb`, `dmesg | tail` (thanks to the GPIO3_C4 hog, the host port should have 5V).
4. HDMI: the screen must show a console (the kernel prints to `console=tty1`).
5. WiFi: `nmcli dev wifi list` (ESP8089 + the wlan-esp8089 overlay are already enabled).

## F. Debug tips when you don't see display/USB yet

- **Console**: by default, kernel logs already go to UART2 + UART1 + HDMI (`extraargs` in
  `/boot/armbianEnv.txt`). If you want to change the primary console (for `/dev/console`), reorder the
  `console=` entries in `extraargs` — the LAST device is the primary console.
- **UART2 vs SD slot**: on the RK3128, UART2 shares pins with SDMMC — the NAND image enables `uart2`
  by default (so you can watch logs), so **the SD slot will not be readable in Linux** (U-Boot
  still reads the SD just fine). Once the system is running stably (SSH over LAN), edit
  `/boot/armbianEnv.txt`: remove `uart2` from `overlays`, add `sdcard-enabled`.
- Available overlays: `usb-otg-host`, `uart1`, `uart2`, `dmc-disabled`, `wlan-esp8089`,
  `emmc-enabled`, `sdcard-enabled`, `gpio2-sdcard-disabled`, `cma-64m`, `v4l2-hantro`, ...

## G. Verifying downloaded files (SHA256)

`output/SHA256SUMS.txt` holds the checksums of every deliverable. On Windows:
`Get-FileHash -Algorithm SHA256 <file>` to compare (the `nand-flash/*` files must be
byte-identical to the original A26 — verified at build time).

## H. Recovery / rollback (the safe way back)

If the XMIO build won't boot or misbehaves:

1. **Back to the original A26 (keep Linux)**: reflash the `A26-release-20260430/.../armbian_rootfs_26.2.img`
   file (the author's original) to the `root` partition (0x6000) following the Section B procedure exactly.
   The bootchain is untouched, so it's done in 2 minutes.
2. **Full return to stock Android**: RKDevTool tab **升级固件 (Upgrade Firmware)** →
   pick the `stock-firmware/update_(VTIDC_XMIO_20160128_for_nandflash).img` file → EraseFlash +
   Download. The box goes back to exactly the factory Android (all Armbian gone).
3. **Root shell over UART**: the serial console is also a login terminal (login: `root`,
   password `1234` the first time — Armbian will ask you to change it). If SSH fails, you can still
   control the box over UART.
4. **U-Boot prompt**: within the first 9-second bootdelay, press any key on UART1 to enter the
   `RK3128 >>` prompt — you can use the XMIO hook (`setenv xmio_fdt_override ...; boot`,
   see Section D), `printenv`, `saveenv`...

## I. One-page process summary (cheat sheet)

```
1. Wire up USB-TTL (UART1 or UART2, 115200 8N1) → open PuTTY.
2. RKDevTool v2.69 → Loader mode (hold reset while plugging USB) → load rk3128_loader_v2.12.263.bin.
3. Download Image: parameter.txt→0x0, uboot.img→0x2000, trust.img→0x4000,
   armbian_rootfs_26.2_xmio.img→0x6000 → Download → reboot.
4. Watch the UART log: DDR → U-Boot → kernel. On kernel panic → capture the log and send it back.
5. If boot completes: SSH root@<ip> (password 1234) → sudo xmio-collect → send /tmp/xmio-report.txt.
6. USB test: plug a stick → lsusb. HDMI test: the screen shows console/getty.
```

## J. Plan B — flash using the stock Android flow (when Plan A is completely silent)

If you already flashed Plan A (Section I) but **UART outputs nothing, HDMI stays dark, no LAN** —
while flashing `uboot.img` on its own from the stock Android firmware does yield U-Boot 2014.10 logs —
use Plan B: **keep the Android boot flow intact** (stock U-Boot + stock-style partitioning +
Android-format boot.img) but with our Armbian content inside. The whole set lives in
`output/planb-stock-uboot/`.

Loader to load: `rk3128MiniLoaderAll(L)_V2.25_ink.bin` (same directory — the stock V2.25 loader,
not the A26 V2.12 loader).

Download Image (the addresses auto-match the parameter file, but declare them explicitly as follows):

| File | Address (hex) | Notes |
|---|---|---|
| `parameter.txt` | `0x0` | partition table + Linux cmdline |
| `uboot-stock.img` | `0x2000` | stock U-Boot 2014.10 (proven to work) |
| `misc.img` | `0x4000` | stock misc (U-Boot needs to read it) |
| `baseparamer-720P.img` | `0x6000` | stock baseparamer |
| `resource.img` | `0x6800` | XMIO DTB (swap in `resource-baseline.img` for A/B testing) |
| `boot.img` | `0xE000` | kernel 6.6.89 + initramfs + resource (second blob) |
| `armbian_rootfs_26.2_xmio.img` | `0x17000` | ext4 rootfs |

Press **Download** → reboot. Expected logs:

```
U-Boot 2014.10-RK3128-01-... (stock banner, as you saw)
GetParam / check parameter success
...
Starting kernel ...
Booting Linux on physical CPU 0x0 ...
Linux version 6.6.89-rk3128+ ...
```

### K. Plan B v3 — MANDATORY: use the new set (round 16)

The v2 set you flashed stalls at `Starting kernel ...` and then goes silent. Analyzing the U-Boot
`bootrkp` flow source + kernel 6.6 revealed 2 root causes (both fixed; the new file set is in the same
`output/planb-stock-uboot/`, SHA256SUMS updated):

1. **DTB missing the /memory node** — the bootrkp flow passes an FDT (no ATAGs), so kernel 6.6
   has no valid RAM info → it dies before printing anything. v3 adds
   `memory@60000000` = 128MiB (matching your box's DRAM log).
2. **Console pointed at the wrong UART port** — the old DTB targets UART1 (0x20064000) while the port
   you're plugged into is a different one (the A26 build also uses UART1 and is silent). v3 enables earlycon on BOTH
   UART0 (0x20060000) and UART2 (0x20068000) + console=ttyS0/ttyS1/ttyS2/tty1 +
   ignore_loglevel → logs come out on whichever port you're on.
3. Dropped `initrd=` from the parameter (0x62000000 is where U-Boot places the KERNEL; the real
   initrd is written by U-Boot into /chosen via `fdt_initrd`).

Reflash exactly per the table above (parameter.txt 0x0, resource.img 0x6800, boot.img 0xE000;
rootfs unchanged). v3 DTB file: `rk3128-xmio-planb.dtb`.

### L. Plan B v4 — fixing the PSCI panic (the kernel boots now!)

Your v3 log: kernel 6.6 boots up, earlycon works, then it panics:
`psci: probing for conduit method from DT` → `__invoke_psci_fn_smc` →
`Bad mode in prefetch abort` (Mode MON_32).

Cause: the DTB inherits the `/psci` node (meant for chains that have ATF/trust.img), but Plan B
runs the stock chain which **has no secure firmware** — the SMC call jumps into an empty
Monitor mode → abort. v4 did:

1. **Remove the `/psci` node** — no more panic.
2. **Enable non-ATF 4-core SMP**: `enable-method = "rockchip,rk3036-smp"` +
   per-cpu `resets` (SRST_CORE0..3) + sram holding-pen 0x10080400 (the bootrom
   mailbox, matching the stock 3.10 design).
3. RAM: the v3 log shows U-Boot fixes up /memory to 1GB on its own — our node is only
   a fallback, no change needed.

**Reflash 2 files** (parameter.txt unchanged): `resource.img`→0x6800,
`boot.img`→0xE000. Expected: no more panic; the kernel carries on through the clock source,
CRU, serial driver (console handover from earlycon to ttyS0), then mounts
`/dev/rknand_root`. If you see `smp: Bringing up secondary CPUs` fail on 3 cores →
accept it (boot on 1 core, send the log so we can fine-tune later).

Technical details: boot.img is a standard Android bootimg (kernel@0x60408000,
ramdisk@0x62000000, second=resource.img containing `rk-kernel.dtb` = our DTB —
stock U-Boot reads the FDT from there). The rootfs flashed at 0x17000 matches `root=/dev/rknand_root`.

### M. Plan B v5 — keep earlycon after handover (flash only the parameter)

Your v4 log: the kernel gets past PSCI, SMP brings up 4 CPUs, the full cmdline is passed, arch_timer runs —
then it stops printing at `console [tty1] enabled / bootconsole [uart8250] disabled`.

Analysis: the console handover happens on **tty1** (the vt console — with no screen attached, it
"prints" into the void), and the 8250 serial driver probes **after** that point. From that moment on,
every printk has no real console to output to → the UART goes silent even though the kernel may
still be running. There is no way to tell "hung" from "running silently".

v5 (new parameter.txt, **other files unchanged**):
1. **`keep_bootcon`** — earlycon is not disabled at handover → all logs (SMP,
   pinctrl, serial, nand, mounting root...) keep showing on UART whether or not the
   console driver comes up.
2. **Move `console=ttyS0` to the end** — ttyS0 becomes the preferred console →
   `/dev/console` (init/systemd) will go out over the UART once the serial driver is up.

**Flash only `parameter.txt`→0x0.** Expectation: the log keeps going much longer. If you see
`smp: Bringing up secondary CPUs` + `CPU1: Booted...` → SMP bootrom mailbox OK.
Wait until the `rknand`/`rknand_root` lines (CONFIG_RK_NAND driver), then mount rootfs.

### N. Plan B v6 — fixing SMP (mailbox @0x10080000) + initcall_debug

v5 log: the kernel gets through many initcalls (pinctrl 4 GPIOs, ramoops, VOP/HDMI...) but
`smp: Brought up 1 node, 1 CPU` — the 3 secondary cores never come up. The v4 set's mistake: I placed
the holding-pen at offset 0x400 in IMEM (following the `sram@10080400` node of the stock
3.10 — that node is just shared SRAM, **not** the bootrom mailbox). The bootrom
mailbox sits at the fixed address **0x10080004/8** (exactly like `smp-sram@0` of
upstream rk3036/rk3066/rk3188/rk3288 — all 4 dtsi are `@0`). The kernel wrote the flag
to 0x10080404 → the secondary core powers on, the bootrom reads the fixed address, doesn't see
the flag → no boot.

v6 fixes 2 things:
1. **DTB**: `smp-sram@0` (reg `<0x00 0x10>`) → the mailbox writes at the right 0x10080004/8 →
   expecting `smp: Brought up 1 node, 4 CPUs`.
2. **parameter**: add `initcall_debug` — the kernel prints `calling <func>+0x..` before
   every initcall. The v5 log stops after `Bluetooth: SCO socket layer initialized` —
   that is only the **kernel's BT framework** (CONFIG_BT built-in, printed on every Linux
   machine, fine even if the box has no BT hardware) — it is the last initcall before
   the hang point; `initcall_debug` will name the function that actually hangs.

**Flash 2 files**: `parameter.txt`→0x0, `resource.img`→0x6800, `boot.img`→0xE000.
Send the log: the last `calling` line before the stop = the culprit.

### O. Plan B v7 — culprit caught: `rockchip_cpuinfo_init` (flash parameter only)

`initcall_debug` pointed right at it: the log stops immediately after
`calling rockchip_cpuinfo_init+0x0/0x18 @ 1` (no `returned` = hanging INSIDE
the function). This function registers the `rockchip,cpuinfo` driver → the probe runs right away → it reads 16 bytes of efuse
via nvmem → hangs silently without printing anything (infinite polling in the
clock/nvmem path).

It does only 1 thing: set the serial/SoC-id for `/proc/cpuinfo` — **cosmetic, safe to
drop**. v7 uses `initcall_blacklist=rockchip_cpuinfo_init` to skip it.

**Flash only `parameter.txt`→0x0.** Keep `initcall_debug` — if it still hangs further on,
the log will name the next culprit; if it no longer hangs → the kernel continues on to
serial/nand/rootfs. (SMP is still 1 core for now — not blocking boot, handle it later.)

### P. Plan B v8 — second culprit: the UART1 probe (flash resource + boot + parameter)

v7 gets past `rockchip_cpuinfo_init` (log: `initcall rockchip_cpuinfo_init
blacklisted`) and runs through initramfs/ext4/squashfs, `ttyS0 at MMIO ... 16550A`
comes up correctly, RGA/mpp/PMU/PL330-DMA/USB2-PHY probe OK... then stops at
`probe of 20064000.serial:0.0` — hanging while probing **UART1** (the `ttyS1`
banner never appears).

Root of it: UART1/UART2 are not wired out anywhere (the user already confirmed the plugged-in port
= UART0) but they remain `status = "okay"` in the DTB from round one. The 6.6 kernel probes
UART1 → it hangs inside `dw8250_platform_driver_init` (suspected clock/pinctrl path,
not yet deeply root-caused — but they are superfluous, so dropping them entirely is the right call).

v8: `serial@20064000` + `serial@20068000` → `status = "disabled"`; the cmdline is trimmed down to
**UART0 only** (`earlycon 0x20060000` + `console=ttyS0`), dropping ttyS1/S2
and earlycon 0x20068000. The console path proven since v5 stays unchanged.

**Flash 3 files: `parameter.txt`→0x0, `resource.img`→0x6800, `boot.img`→0xE000.**
Keep `initcall_debug` + the cpuinfo blacklist — if it still hangs, the next
culprit will still name itself.

### Q. Plan B v9 — kernel self-checks the clocks (flash only `boot.img`→0xE000)

**The nature of the problem, discovered by analyzing the v7/v8 logs:** the whole log has
timestamps `[0.000000]` and every initcall is `after 0 usecs` — the clock the kernel reads
to measure time (clocksource/sched_clock, specifically the cp15 counter `CNTVCT`
of the ARM arch timer) **is not running**. The stock Android bootchain (U-Boot 2014.10)
never enables this counter before jumping into the kernel. Consequence: every "wait by
time" inside a driver (timeout, sleep, wait) can hang forever — the hang
point drifts (v7 at the UART1 probe, v8 at the tail of the UART0 probe) because whichever driver
hits a `wait` first stops right there. This is the root cause, not a UART bug.

**v9 does 2 things:**
1. **Self-measure right at boot**: the kernel prints `V9DIAG: ... CNTVCT ... FROZEN/TICKING`,
   along with the state of the DW timer `0x20044000`, jiffies, sched_clock and the timer gate
   clocks in the CRU — pinpointing exactly which one runs and which one is dead.
2. **Self-rescue the boot (auto-bailout)**: if CNTVCT is frozen, the kernel **drops the arm arch
   timer** and uses the DW timer `0x20044000` as the sole tick source; sched_clock
   falls back to jiffies (10ms resolution — enough to boot). At the same time it prints a step-by-step
   probe trace of UART0 — if it still hangs, the log will point to the exact line.

**Flash exactly 1 file: `boot.img` → `0xE000`.** (The kernel changes; DTB,
parameter, resource stay unchanged from v8.)

Expected log:
```
V9DIAG[timer-of]: CNTFRQ=24000000 CNTVCT 123 -> 123 (FROZEN)
V9DIAG: cp15 counter FROZEN - skipping arm_arch_timer (rk_timer keeps the tick...)
...
V9DIAG: dw8250 stage uartclk=24000000
V9DIAG: dw8250 probe-done
```
If you see `probe-done` and the boot continues to rootfs — the timestamp
bottleneck has been passed. Send the full log over UART.

### R. Plan B v10 — blocking SMC + enabling 4-core SMP (flash only `boot.img`→0xE000)

**v9 log results (confirmed):**
- 100% accurate diagnosis: `CNTFRQ=0 CNTVCT … (FROZEN)` → the auto-bailout
  works, timestamps start running for real (`0.010000 → 10.280000`), and the UART0 probe
  **finishes cleanly** (`dw8250 probe-done`, `ttyS0 … is a 16550A`).
- But the boot dies on a **new error**: `Bad mode in prefetch abort …
  LR is at __invoke_sip_fn_smc … r0: 82000009`. That is the `SMC
  0x82000009 (SIP_SHARE_MEM)` instruction issued by `rockchip_drm_init → rockchip_gem_get_ddr_info
  → sip_smc_get_dram_map`. On the stock chain **no ATF/secure
  monitor** exists to catch the SMC instruction — the CPU jumps into Monitor mode via garbage MVBAR and dies.
  (Same nature as the PSCI panic of v3.)
- SMP is still 1 CPU — exactly as predicted: `arch/arm/Makefile` once wrapped
  `machine-$(CONFIG_ARCH_ROCKCHIP) += rockchip` inside `ifndef CONFIG_ARM_PSCI`,
  so the whole of mach-rockchip (SMP ops, machine desc) was never built at all.

**v10 does 3 things:**
1. **Block every SIP SMC**: `__invoke_sip_fn_smc` no longer executes `SMC` but
   returns the error `SIP_RET_SMC_UNKNOWN (-1)` + prints
   `V10DIAG: blocked SIP SMC fn=0x…`. All consumers handle the error cleanly
   (a failing DMC probe is not fatal, `rockchip_gem_get_ddr_info` null-checks OK) —
   no path remains that touches Monitor mode via SIP.
2. **Enable mach-rockchip** (drop the `ifndef CONFIG_ARM_PSCI` guard): SMP ops
    `rockchip,rk3036-smp` (bootrom mailbox: power-domain on via per-CPU
    reset → write `secondary_startup` + `0xDEADBEAF` to SRAM `0x10080ff0`
    (smp-sram@0 in the DTB) → `sev`) and the machine desc "Rockchip (Device Tree)"
    are now really linked (verified: `__cpu_method_of_table_rk3036_smp`,
    `rockchip_boot_fn`, V10DIAG strings in vmlinux).
3. Shrink the diagnostic busywait (40M→8M loops) to make boot less slow.

**Flash exactly 1 file: `boot.img` → `0xE000`** (v10, md5 `2c103b69a1baea8e83899dc08bc35b6f`).
DTB/parameter/resource stay unchanged from v8/v9.

Expected log (differences from v9):
```
V9DIAG[timer-of]: CNTFRQ=0 CNTVCT … (FROZEN)          <- same as v9
V9DIAG: cp15 counter FROZEN - skipping arm_arch_timer  <- same as v9
...
V10DIAG: rockchip machine init (mach-rockchip active)
V10DIAG: rk3036 smp_prepare_cpus enter
V10DIAG: rk3036 smp_prepare_cpus done ncores=4
V10DIAG: blocked SIP SMC fn=0x82000009 (no ATF on stock chain)
smp: Bringing up secondary CPUs ...
smp: Brought up 1 node, 4 CPU
SMP: Total of 4 processors activated
```
Three branches for reading the log:
1. **4 CPUs + boot continues to rootfs** → win; send the full log to confirm.
2. **Stops at `smp_prepare_cpus` / missing the "done ncores=4" line** → the problem lies
   in the SRAM/power-domain path — send the log, we'll fix further.
3. **`blocked SIP SMC` appears many times, then boot is slow/hangs at another driver**
   → look at the last line before it goes silent; SIP is already safe, the problem is that driver.

### S. Plan B v10.1 — no more duplicated log lines (flash only `parameter.txt`→0x0)

**Booted into rootfs (confirmed by user) — the main milestone of Plan B.**

In the v10 log every line prints twice because the cmdline has `keep_bootcon`: it keeps earlycon
(the `uart8250` bootconsole) alive even after the real console `ttyS0` registers, so
every printk message is emitted through both consoles at once. Signs in the log:
`printk: debug: skip boot console de-registration.` + every line after
`console [ttyS0] enabled` is x2.

**v10.1 fix**: remove `keep_bootcon` from the CMDLINE in `parameter.txt`.
`earlycon` stays (needed for output before ttyS0 registers); when `ttyS0`
takes over, the kernel itself prints `printk: bootconsole [uart8250] disabled` and from then on
each line prints only once.

**Flash exactly 1 file: `parameter.txt` → `0x0`** (sha256
`27d704285dc5b1a0f90d7f46f46fbd5d2634dadac6b1d767fead01922497e092`).
`boot.img` stays at v10. The debug parameters `initcall_debug`,
`ignore_loglevel`, `earlycon` will be dropped in the final release once
HDMI/USB are stable — for now they are kept for continued debugging.

After booting with v10.1, run on the rootfs (if you got into a shell) and send back:
```
nproc
dmesg | grep -E "smp:|Brought up|V10DIAG|blocked SIP|FROZEN"
dmesg | grep -iE "hdmi|vop|drm|connector"
dmesg | grep -iE "usb|ehci|ohci|dwc"
lsusb; ls /dev/dri 2>/dev/null
```

### T. Plan B v11 — diagnosing the hang waiting for rootfs + rootdelay=60 (flash `boot.img`→0xE000 AND `parameter.txt`→0x0)

**v10.1 status**: boot reaches initramfs (`Loading, please wait...` +
`Starting systemd-udevd`) then goes silent — that is initramfs-tools waiting for the root device
`/dev/rknand_root`. The kernel has finished running all initcalls (we see
`Freeing unused kernel image` + `Run /init`), i.e. the NAND driver
`CONFIG_RK_NAND=y` (built-in, with symbols `rk_ftl_init`/`rknand_probe`
in vmlinux) **did run** — but the log contains no rknand line at all.
The driver has 2 **silent** exit paths in the source: probe abort when
`boot_media==2` (return -1, no print), and `nandc0 NULL` in
`rknand_dev_init` (return -1, no print). The disk is never created →
`rootwait` waits forever.

**v11 changes**:
1. `tools/v11-patch.py` — adds `V11DIAG` at 7 points across the chain
   `drivers/rk_nand/`: probe enter → idb magic + boot_media_raw → probe
   done → nandc0/nandc1 regbase → (nandc0 NULL now PRINTS instead of staying silent) →
   rk_ftl_init ok + capacity → nand_blk_register ok + partition count.
2. `parameter.txt`: `rootwait` → `rootdelay=60`. If the root device still
   doesn't appear after 60s, the initramfs **drops an emergency shell over UART**
   (Prompt `(initramfs)`) instead of hanging silently — root= rknand_root is kept.

**Flash 2 files**: `boot.img`→0xE000 + `parameter.txt`→0x0 (loader V2.25,
Download → reboot).

**Reading the log — 3 branches**:
1. **NAND alive**: `V11DIAG: rknand probe enter id=0` → `idb magic
   0x44535953 boot_media_raw ...` → `probe done` → `nandc0 ...` →
   `rk_ftl_init ok capacity ...` → `nand_blk_register ok parts=N`
   (N≥7 with `root`) → the line `rknand: ... root: ... MB` → boot continues into
   Armbian (systemd banner). If systemd crashes → that is a rootfs problem,
   NO LONGER a flashing problem.
2. **Probe dies midway**: the log stops right after some V11DIAG line —
   the last line is exactly the point of death (send the entire log).
3. **No V11DIAG line at all**: the platform device doesn't match
   (the `nandc@10500000` node may be taken over by the mainline NFC node at the
   same address, or the hclk clock is absent → probe defer/early fail). Send the
   full log, we'll inspect the DTB.
4. **Emergency shell `(initramfs)` appears after 60s** (nothing from
   branches 1–3): type in the UART shell:
   ```
   cat /proc/cmdline
   ls -la /dev/rknand* /dev/mtd*
   dmesg | grep -iE "nand|ftl|V11DIAG"
   cat /proc/partitions
   ```
   then send the output. This shell stays alive long enough, no rush.

### U. Plan B v12 — root cause of the rootfs hang settled: FTL blob race (GC vs vendor-storage), background GC disabled + blkid avoided (flash only `boot.img`→0xE000)

**The v11 log has proven**: the NAND chain is HEALTHY — probe ok (idb magic SYSD,
boot_media 1), FLASH ID `98 d7 84 93 72 50`, FTL 5.0.63, `ftl_init 0`,
capacity 3744 MB, **`nand_blk_register ok parts=6` → `/dev/rknand_root`
exists from 17.66s**. But boot still goes silent after `Starting systemd-udevd`.

**Root cause (evidence)**:
- `/scripts/init-top/udev` (initramfs): start udevd → `udevadm trigger`
  → `udevadm settle`. The next line `Begin: Loading essential drivers`
  NEVER prints → hung inside settle.
- Rule `60-persistent-storage.rules:128` runs the `blkid` builtin on every
  block device → reads the superblock `rknand_*` → kernel holds mutex
  `g_rk_nand_ops_mutex` for the entire duration of the read.
- GC thread (`kthread_run` at 17.66s, `rk_ftl_gc_do=1` IMMEDIATELY)
  calls `rk_ftl_garbage_collect()` into the FTL blob (vendor assembly, not
  re-entrant) WHILE `rk_ftl_vendor_storage_init()` also calls the blob —
  right around 17.0–17.65s there are lines `ReadRetry ... ecc=28
  err=ffffffff` and `vendor storage init failed`. The GC gets stuck forever holding
  the mutex → every read blocks forever → settle waits forever.

**v12 changes** (kernel + initramfs, both inside `boot.img`):
1. Kernel `drivers/rk_nand/rk_nand_blk.c`: `rk_ftl_gc_do = 0` (background GC
   off — kills the race; FTL cache still flushes via REQ_FUA), + `V12DIAG` prints
   the first 8 requests (dev/sec/nsec → done) and GC enter/done if it runs.
2. Initramfs: rule `59-rknand-noblkid.rules` (udev does not blkid
   `rknand*`), marker `INITRD-DIAG: udev trigger done / settle done`,
   and a **1-sector read probe** on `/dev/rknand_root` right before mountroot:
   `INITRD-DIAG: probe read OK` = the read path is alive.

**Flash exactly 1 file: `boot.img` → 0xE000** (parameter unchanged —
note that `rootdelay=60` makes /init sleep 60s after "Loading essential
drivers", don't mistake that for a hang).

**Reading the v12 log**:
1. `INITRD-DIAG: udev settle done` → `probe read OK` → ext4 mount →
   systemd banner → **boot succeeded**.
2. `rq start ...` with no `rq done` → the FTL read is still stuck (different from the race) —
   send the log.
3. `udev settle done` never appears → hung elsewhere in udev — send the log.
4. Mount completes but systemd fails → rootfs problem, send the log.

## V. v13 — Hanging right at the udevd milestone IS the 1-timer-4-CPU race, not udev/FTL

The v12 log pins down 2 important facts:

1. **Not a single `V12DIAG: rq start` line** — no rknand read request had
   been issued yet → blkid/FTL is not involved in this hang point.
2. **No sign of the marker `INITRD-DIAG: udev trigger done`** even though it sits
   RIGHT AFTER the 2 `udevadm trigger` commands → the hang happens earlier, in the
   `udevd --daemon` + 2 trigger commands area — i.e. right as userspace starts
   forking processes and the CPUs start toggling idle in rapid succession.

**Root cause (v13-analysis1/2 + timer-rockchip.c):**

- The DTB has only **1 timer node** → the kernel registers exactly 1 clockevent
  (`rk_timer clkevt`, cpumask = all 4 CPUs). The log confirms: **no
  `rk_timer clksrc registered`** → clocksource = jiffies,
  `sched_clock: 32 bits at 100 Hz` — all timekeeping runs on ticks
  from that very timer.
- The 3 secondary CPUs only have a local *dummy timer* → they must use **tick broadcast**
  from that very same global timer.
- **ONESHOT** mode (NO_HZ + high-res) requires **re-programming the timer
  (disable→load→enable) on every tick and every CPU idle entry/exit**. CPU0
  re-programs without a lock, CPUs 1-3 re-program under `tick_broadcast_lock`
  → **2 CPUs race to write the same unlocked timer register** → lost
  arm → timer interrupts stop → **a totally silent hang** (no softlockup,
  no hung_task — both of them need the tick to run!).
- 100% match: v10.1/v11/v12 die at the same spot regardless of the tweaks;
  before /init the kernel runs almost single-threaded, so it never hit the race.

**v13 changes** (`boot.img` only):

1. Kernel `drivers/clocksource/timer-rockchip.c`: drop
   `CLOCK_EVT_FEAT_ONESHOT` → the timer runs in **auto-reload PERIODIC**,
   programmed exactly once at boot → **no more race window**. Same as
   how the vendor 3.10 kernel runs the global timer on this SoC.
2. Config: `HZ_PERIODIC=y`, disable `NO_HZ`, disable `HIGH_RES_TIMERS` (a steady
   100 Hz tick like stock Android; accepting the loss of the high-res timer —
   irrelevant for a TV box).
3. `V13DIAG` heartbeat: every 5 seconds prints `hb jiffies=... ctrl=... cur=...
   ce_state=...` — if the heartbeat **freezes** while the UART still prints =
   the tick is dead; if the UART dies but a later boot's pstore still shows the heartbeat =
   only the UART died, the kernel is still alive.
4. `V13DIAG: set_next_event cycles=...` is a trap: periodic mode must NOT
   EVER be called — if it appears, an assumption was wrong, send the log.
5. Initramfs: an `INITRD-DIAG` marker around **each individual command** in the
   udev script (script enter / uevent_helper / udevd started / trigger
   subsystems done / trigger devices done / settle done) + a **15s watchdog**
   printing `ps`, `/proc/interrupts`, `/proc/timer_list`, the wchan/stack
   of udevd-udevadm + a final report at 45s.

**Flash exactly 1 file: `boot.img` → 0xE000** (new md5 after building;
parameter unchanged). Wait **at least 90 seconds** after the last line.

**Reading the v13 log** (look for `V13DIAG` + `INITRD-DIAG`):

- Winning branch: the udev markers run to the end → `probe read OK` → `mountroot
  returned` → ext4 → systemd banner → **SUCCESS** (the timer race is
  fixed). A `V13DIAG: hb ...` heartbeat line every 5s is normal.
- `INITRD-DIAG: WATCHDOG 15s` appears together with ps/interrupts → the kernel is
   still alive, userspace is stuck — send the entire watchdog block.
- Heartbeat stops + watchdog silent → the tick/timer died somewhere else → send the log,
   we'll have `ctrl/cur/ce_state` from near the moment of death.
- `V13DIAG: set_next_event cycles=...` → periodic was violated → send the log.
- After `settle done`, hanging at mount → re-check branches 2/3/4 of section U
   (FTL read / rootfs).

## W. v14 — Blocking the suspects that kill the system at second 20.7 (pm-domain keepon release + clk gating)

The v13 (fixed) log settles it: the udev markers print up to `trigger subsystems begin`
(21.5s) but the **15s watchdog never prints** → `sleep(15)` never
completes → **all timers/hrtimers die within the 21.4–21.6s window**,
right after the 20.73s `late_initcall_sync` chain (`clk_disable_unused`,
`rockchip_pd_keepon_release`, `genpd_power_off_unused`).

**Suspect no. 1**: `rockchip_pd_keepon_do_release` — at boot genpd
holds the power domains at ALWAYS_ON; this initcall clears the flag and queues
**powering the domain off** when idle. Our DTB has `pd_vio` (the VIO domain) with
keepon=true → at exactly 20.7s the kernel tries to power off VIO; if the PMU kills the domain while the
system still depends on it (bus/NIU not idling properly) → a totally silent
death (no panic — the power is cut, not an exception).

**v14 changes** (`boot.img` only, initramfs unchanged):

1. **Lock the keepon release**: every `keepon_startup` domain (VIO, MSCH)
   stays ALWAYS_ON forever — never powered off again. Log:
   `V14PDIAG: keepon release disabled by v14`.
2. **V14PDIAG** prints on every power domain off/on:
   `V14PDIAG: domain 'vio' -> power 0` — if you still see power 0 before
   the hang, the culprit is elsewhere.
3. **Block clk gating**: `clk_disable_unused` only LOGs the name of each clock
    (`V14CLK: would gate: <name>`) but **does not shut it off** — the last V14CLK
    line right before the hang = the culprit's name.
4. **Enhanced heartbeat `V13HB:`** writes **directly to the UART0 hardware**
   (0x20060000, bypassing printk) every 5s with the per-CPU timer interrupt counters —
   if the kernel's UART console dies but the tick is still alive, we still see
   `V13HB` — separating "dead tick" vs "dead console".
5. **V14DEAD**: self-reports when the tick freezes (delta>6) or when the number of
   online CPUs collapses to 1.

**Flash exactly 1 file: `boot.img` → 0xE000**
md5 `476d95191e2b883c7392f4d98dcbf1a3` — parameter unchanged. Wait
**at least 90 seconds** after the last line.

**Reading the v14 log**:
1. `V14PDIAG: keepon release disabled` → trigger/settle continues →
   `probe read OK` → systemd banner → **SUCCESS** (suspect #1
   confirmed).
2. Still hanging + last V14CLK line = `<clock-name>` → send the log; we lock
   that clock for good.
3. `V14PDIAG: domain 'xxx' -> power 0` right before the hang → another
   domain is still being shut off → send the log, lock the next one.
4. Hanging while `V13HB:` still prints every 5s → the tick is alive, only console/printk
   is dead → a completely different fix direction.
5. `V14DEAD: ...` → the tick is truly dead → send the log (with the per-CPU irq counters).

### W.1 — v14 RESULT (ACTUAL LOG): KERNEL BOOT CHAIN FULLY UNBLOCKED

The box's v14 log confirms:

- `V14CLK: would gate: sclk_timer0...` — **the real culprit of v10.1→v13**
  is precisely `clk_disable_unused` (20.7s): it gates `sclk_timer0` —
  the clock signal of the very timer that runs the tick! (Proof: it appears in
  the "would gate" list = enable_count 0; our vendor-style timer driver
  never calls clk_enable, it lives off the reset default.) v14 locks the gating →
  no more hangs.
- `V14PDIAG: keepon release disabled` — the VIO/MSCH domain stays ALWAYS_ON.
- **The whole udev chain completes for the first time**: `trigger subsystems
  done` → `trigger devices begin` → `udev trigger done` → `settle
  begin` → `udev settle done` → `udev script exit`.
- Heartbeat `V13HB:` steady at 5.04s, irq=+504 each beat (exactly 100 Hz), all
  of it on CPU0, `load=239999` = 24 MHz/100 Hz ✓ — tick perfectly healthy.
- FTL reads clean: every `rq start` has a matching `rq done res=0`.
- `probe read OK` → fsck runs → **stops at an ext4 data error on the rootfs**
  (`Inode 2741 has an invalid extent node` → status 4) → drops into
  the `(initramfs)` emergency shell. This is a rootfs DATA error (from the
  flash or from the FTL), NO LONGER related to kernel/boot.

**Emergency action right at the `(initramfs)` prompt (type over UART):**

```
fsck.ext4 -fy /dev/rknand_root
```

- It runs for a few minutes; many CLEARED/FIXED lines are normal (the V13HB heartbeat
  still prints interleaved — normal).
- If it ends with `FILE SYSTEM WAS MODIFIED` / clean → type `exit` → boot
  continues → expect the Armbian systemd banner.
- (Optional, if `tune2fs` is available): `tune2fs -O has_journal /dev/rknand_root`
  to recreate the removed journal; if unavailable, skip it — booting
  without a journal still works.
- If fsck -y cannot fix it or the continued boot still fails → send the log; plan
  B is to reflash `armbian_rootfs.img` → 0x17000 (a clean image will be rebuilt
  if needed).

### W.2 — rootfs v15 (REFLASH when the old rootfs is too broken for fsck)

It has been determined: **both the original A26 image and the shipped build pass `e2fsck -fn` CLEAN
on the machine** → the corrupted data is in the NAND write path during flashing (FTL/loader),
not the source file. Stop fsck (Ctrl+C / power off) and flash the rebuilt
v15 build:

**`output/armbian_rootfs_v15_xmio.img` → `0x17000`** (flash exactly this 1
file only; keep the v14 `boot.img` unchanged)
- sha256 `c09cbd03435cbf8cb719212418fec2d0271249ab9e67a97443c5a049c3422780`
- Contents: modules matching EXACTLY the running v14 kernel
  (modules_install from the build tree), **journal OFF** (`^has_journal` —
  FTL-safe: the stale-journal error is exactly what killed the boot; fsck -fy
  repairs cleanly when needed), `/etc/fstab` without the `/` entry (root is mounted
  by the initramfs), `serial-getty@ttyS0` enabled (login over UART), the image was
  `e2fsck -fy` clean before shipping.

**Flashing procedure (RKDevTool Download Image):**
1. Just 1 line: address `0x17000`, the v15 file. DO NOT touch the other lines.
2. Enable verify if the tool has it; **do not cut power/interfere** until it reports
   success (1.1 GB, a few minutes).
3. Reboot → expect: the familiar udev chain → `Loading essential drivers
   ... done` (a rootdelay=60 pause of ~60s — normal) → `probe read
   OK` → quick fsck (clean fs, no journal) → Armbian systemd banner
   → **login prompt on UART0**. The `V13HB` heartbeat still prints every 5s
   (normal). Send the full log.

## X. v15 RELEASE — Clean console, fast boot (the long-term build)

Once the v15 rootfs runs well, this is the "sleeps quietly" build: **remove all
periodic instrumentation** (V13DIAG hb every 5s, V13HB direct-to-UART,
V12DIAG on IO, V14CLK/V14PDIAG, initcall spam) and clean up the cmdline.

**Flash 2 files:**
| File | Address | Notes |
|---|---|---|
| `planb-stock-uboot/parameter.txt` | `0x0` | clean cmdline: drop `initcall_debug`, `ignore_loglevel`, `rootdelay=60` |
| `planb-stock-uboot/boot.img` | `0xE000` | kernel release (md5 `7658e3b20a27b7b6ead03eace6e8b187`) |

- Why a new kernel build is needed: `ignore_loglevel` in the cmdline renders every
  `dmesg -n` command ineffective, and `V13HB` writes straight to the UART registers
  (bypassing printk) — no software can turn it off. The release build removes both
  at the source.
- **Keep all the functional fixes**: PERIODIC tick (no reprogramming),
  clk_disable_unused not gating (guarding against clock topology bugs),
  pm-domain keepon not released, rknand background GC off, skip arch-timer
  when cp15 is dead, SIP guard.
- After flashing: boot is ~60s faster (no rootdelay), the console shows only
  standard messages (Armbian banner + login), `dmesg` still fully readable
  when needed. Two boot-time lines are kept: `V9DIAG: rk_timer clkevt
  registered freq=24000000` and `V11DIAG: rknand probe enter` (printed once
  at boot, for later diagnostics).
- Boots clean without the ext4 journal — remember: **no abrupt power cuts**,
  shut down with a command (`poweroff`/`reboot`); if power is lost, fsck will run
  and repair on the next boot.
\n
## Y. v15.1 — Persistent Ethernet MAC (no more random on each boot)

Cause: the NAND vendor storage init fails inside the FTL (IDB region,
ReadRetry/ECC) → `rk_vendor_read/write(-1)` → kernel generates a random MAC
on every boot → DHCP keeps handing out a new IP.

Fix: insert `local-mac-address = [02 31 28 16 01 28];` into the
`ethernet@2008c000` node of the DTB — `stmmac` uses this MAC straight from probe,
the vendor hook never runs. The MAC is chosen as locally-administered
(0x02), mnemonic 3128 + 2016-01-28.

**Flash 2 files:**
| File | Address | md5 |
|---|---|---|
| `planb-stock-uboot/resource.img` | `0x6800` | `00c0cf8ed4545044d9aa4d368b2fa89e` |
| `planb-stock-uboot/boot.img` | `0xE000` | `0b7243bebebaa1adb66c1e5bff7356bc` |

- New DTS: `work/xmio-planb-v9.dts` (v8 + MAC); rebuild the DTB with
  `tools/planb-v15.1.sh`.
- If you find the device's **original MAC** (the router's DHCP lease history
  from the Android era, or a sticker on the box shell): report it, edit 1 line
  in `planb-v15.1.sh` (the `MAC=` variable) and rebuild in 2 minutes.
- If you have a **second box of the same model** on the same LAN: the MAC must change (no
  duplicates allowed) — edit the `MAC` variable and rebuild.

## Z. v16 — SD card enabled, FTL background GC re-enabled, codec silenced

Diagnosis from the user's red dmesg (4 groups):

| Red log | Nature | v16 handling |
|---|---|---|
| `mmc2: Failed to initialize a non-removable card` | **wifi SDIO** @10218000, not TF. The box has no wifi firmware in Armbian | leave as is, harmless |
| `FtlWrite: lpa error:ffffffff` + slow IO + repeated `ReadRetry ecc=28 err=ffffffff` | **FTL background GC disabled since v12** (falsely suspected — v14 proved the freeze was the clock timer). The FTL ran out of free blocks → mapping errors (lpa ffffffff), mapping pages 0x10706e–77 fail ECC reads | **re-enable GC as the vendor original does** (`gc_do=1` init + re-arm), add a `v16_ftl_ready` flag so GC only opens after vendor-storage init returns (closes the v11 race window) |
| `i2c-4: of_i2c: modalias failure on /hdmi@20034000/ports` | harmless: HDMI registers its own I2C adapter (DDC), of_i2c tries to create a device from the `ports` node | not needed |
| `sip_smc_get_dram_map: request share memory error` | no ATF (Plan B chain), the SMC stub returns an error | unfixable, harmless |
| `mpp_rkvdec ... clk_cabac` + `rk_iommu ... MMU_DTE_ADDR` | the vendor codec driver needs vendor clocks/resets missing from the mainline DT; hardware decode never ran | **disable the 6 codec+iommu nodes** (hevc, vepu, vdpu, iep, 2 iommu) |

**SD card**: root cause — the `mmc@10214000` node (SDMMC) is
`status = "disabled"` in the DTB. v16 enables it: `okay` + `broken-cd`
(polling detect, no dependence on a CD wire) + `cap-sd-highspeed` +
a 200ms delay. Insert the card before or after boot, either works (poll ~1s).

**Flash 2 files:**
| File | Address | md5 |
|---|---|---|
| `planb-stock-uboot/boot.img` | `0xE000` | `6290e7ced46cbb0a4750f0c493c6055e` |
| `planb-stock-uboot/resource.img` | `0x6800` | `2fdf4544d6441fa45e73a24fe50cae09` |

**HDMI**: the inno_hdmi.c driver HAS rk3128 (`rockchip,rk3128-inno-hdmi`
match, phy config included), node `okay`, VOP bound — but no picture yet.
Needed from the user: the full `dmesg | grep -iE 'hdmi|vop|drm'` output +
`ls /sys/class/drm/` + the connector status; will handle it next round.

## Z.1 — v16.1: force HDMI on via cmdline (1080p60 force-enable)

The user's log shows: HDMI bind OK (`bound 20034000.hdmi`), the connector
`card0-HDMI-A-1` exists, but **HPD/EDID return nothing at boot**
(`Cannot find any crtc or sizes` @2.95s). Step 1: force enable via
the cmdline `video=HDMI-A-1:1920x1080@60e` (`e` = enable regardless of HPD/EDID).

**Flash 1 file:** `planb-stock-uboot/parameter.txt` → `0x0`
(md5 `bdbc762dd4bbcaab058fb630440c389c`; previous cmdline backup:
`parameter.txt.v16.bak`).

Expected outcomes:
- **1080p picture appears** → the video path (phy+encoder) is OK; the fault remaining is only
  in HPD/EDID — next round fixes detection properly (HPD IRQ / DDC).
- **Still black** → a deeper fault in the phy/encoder — send along:
  ```
  cat /sys/class/drm/card0-HDMI-A-1/status
  cat /sys/class/drm/card0-HDMI-A-1/modes
  od -A x -t x1z /sys/class/drm/card0-HDMI-A-1/edid | head -4
  cat /proc/interrupts | grep -i hdmi
  dmesg | grep -iE 'hdmi|vop|drm'
  ```
  (last 2 commands: plug/unplug the HDMI cable a few times and send the output again — to see
  whether the IRQ count rises.)
- If 1080p60 stutters/won't lock on the TV: try 720p60 — change
`video=HDMI-A-1:1920x1080@60e` to
`video=HDMI-A-1:1280x720@60e` in parameter.txt and reflash.

## Z.2 — v17: timer channel 2 → clocksource/sched_clock (10ms jank gone)

Cause: the DTB has only 1 timer node → the driver uses it as clockevent,
clocksource+sched_clock never init → the kernel measures with jiffies
(10ms steps): ping/mtr round to 10ms, dmesg timestamps always .000000.
Fix: add a `timer@20044020` node (channel 2, same xin24m + pclk; the driver
already has rk_clksrc_init, only the node was missing). The kernel zImage is UNCHANGED.

**Flash 2 files** (boot.img md5 `566b31202b6e0f187be809e736e60385` @
`0xE000`, resource.img md5 `c1901e0b2fb6e9a80052647b4899be0e` @
`0x6800`).

Verify: `dmesg | grep V9DIAG` must now also contain
`V9DIAG: rk_timer clksrc registered freq=24000000`;
`cat /sys/devices/system/clocksource/clocksource0/current_clocksource`
= `rk_timer`; new dmesg timestamps carry micro-seconds.

## Z.3 — Slow IO: diagnosis = NAND MLC worn out (EC ~11.5k)

/proc/rknand figures from the box: totle_write 859,711 MB / die 4GB
(~215 full-die cycles), totle_read 530,815 MB, bad blk 55, min/max
EC 11,258/12,012, Read Err 1,314. GC + FTL healthy (error 0, free sb
489) after v16 — the 776 kB/s speed is the physical limit of worn cells,
every read must run a retry sweep. There is NO definitive software fix.

Move 1 currently being tried — **bad_nand=1**: NANDC 150→50 MHz (looser timing for
weak cells), more FTL reserved blocks, retry forced-on. File:
`planb-stock-uboot/parameter.txt.badnand1` (md5
`18b0efb483e3a6ccbd34eb1c4e5f5649`) flash @`0x0` (replaces the regular
parameter). Verify: `dmesg | grep 'clk rate'` →
`rknand_probe clk rate = 50000000 (bad_nand=1)`. Comparison:
`dd if=/dev/rknand_root of=/dev/null bs=1M count=256 2>&1`.
Back to the old one: reflash `parameter.txt` (no bad_nand) @0x0.

Move 2 (not done yet): dd speed by region (0/768/3840 MB) — if slow
uniformly across all regions = uniform wear, erase+reflash of the whole NAND only helps
the FTL rebuild its LUT (faster boot), it does not rescue the speed.

## Z.4 — v17.2: FIXING THE ROOT CAUSE of slow IO — usleep_range quantized to 20ms/page

The decisive measurement: 50 MHz (bad_nand=1) and 148.5 MHz give the
**identical** speed (~770 kB/s) → the bottleneck is a fixed
per-time cost, not bandwidth. Decoding: 16KB ÷ 767 kB/s =
**20.9 ms = 2 jiffies ticks (HZ=100)**. The culprit: the FTL blob
(rk_ftlv5) polls NAND with `usleep_range(1..5 µs)`; the kernel we run
has NO high-res timers (trimmed since v13) → each sleep = a full
10ms. 2 sleeps/page → 20ms/page. (Worn-cell EC ~11.5k is real
but is NOT this bottleneck.)

Fix: 4 `usleep_range` call sites → `rk_ftl_udelay` (busy-wait µs,
independent of the timer subsystem). Kernel rebuild.

**Flash 2 files:**
| File | Address | md5 |
|---|---|---|
| `planb-stock-uboot/boot.img` | `0xE000` | `5a9a44c6049c8fa429f5770d34f23f4d` |
| `planb-stock-uboot/resource.img` | `0x6800` | `c1901e0b2fb6e9a80052647b4899be0e` |

Re-measured (correct test procedure this time — with drop_caches):
```
echo 3 > /proc/sys/vm/drop_caches
dd if=/dev/rknand_root of=/dev/null bs=1M count=256 2>&1
dd if=/dev/rknand_root of=/dev/null bs=1M skip=768 count=128 2>&1 | tail -1
```
Expected: jump from ~770 kB/s to **several MB/s** (the die's real limit).
After confirming, you may reflash `parameter.txt` (without bad_nand)
to return NANDC to 150 MHz — speed will be virtually unchanged, but keeping
bad_nand=1 is also harmless (wider timing = safer for worn cells;
your call).

## Z.5 — v17.2 on-device results + v18: HDMI poll fallback

**User results (v17.2)**: raw read 256MB = **7.5 MB/s** (from 767
kB/s — ×10), the 768MB region = 8.1 MB/s, **boot 2 minutes → 30 seconds**.

**v18** — HDMI "more stable" step 1: connector fallback polling.
Root cause of "Cannot find any crtc or sizes": the connector was only polled
via HPD IRQ; if the IRQ never fires / the cable is plugged in after init, the EDID is never
read. Our HDMI node = identical to mainline (nothing missing in DT),
so patch the driver: `polled |= CONNECT | DISCONNECT` (tools/
v18-hdmi-poll.py, marker V18HPD) — DRM runs detect() itself every ~10s,
and if the HPD bit reads correctly the EDID is fetched on the first poll.

**Flash 2 files:**
| File | Address | md5 |
|---|---|---|
| `planb-stock-uboot/boot.img` | `0xE000` | `e7f76c4ac37e41eaf3d01585d108ba76` |
| `planb-stock-uboot/resource.img` | `0x6800` | `c1901e0b2fb6e9a80052647b4899be0e` |

After flashing, run the HDMI diagnostic suite (wait ~15s after boot, then run):
```
cat /sys/class/drm/card0-HDMI-A-1/status
cat /sys/class/drm/card0-HDMI-A-1/modes
od -A x -t x1z /sys/class/drm/card0-HDMI-A-1/edid | head -4
grep -i hdmi /proc/interrupts
# unplug/replug the cable twice, then rerun the command above
```
- `status = connected` + `modes` has a list + `edid` 128+ bytes:
  EDID is alive — remove `video=HDMI-A-1:1920x1080@60e` from parameter.txt
  (reflash the parameter without force) and the native mode will be auto-selected.
- `status = disconnected` even with the cable plugged in: HPD bit dead — needs further
  digging (GRF/pin), keep force mode for now.
- `status = connected` + empty `edid`: DDC i2c fault — check the pclk rate.

## Z.6 — v18 on-device results: HPD IRQ + EDID ALIVE. v18.1 native mode

User diagnostics (v18): status flips connected/disconnected correctly on every
plug/unplug; HPD IRQ GIC-0 77 climbs 2→158→227→269; EDID valid (TV id
`4d 67 a8 27`, preferred 1920x1080@60, 70+ modes). All three HDMI layers
alive. Cause of the initial black boot: the TV needs a few seconds of handshake, the kernel
finishes HDMI init at 2.9s, no re-detect → the v18 poll fallback self-heals it.

**v18.1 — parameter.txt.native** (md5 `8a1c78811d2c83b783115d426612bb02`,
flash @`0x0`): drops `video=HDMI-A-1:1920x1080@60e` — native mode per
the EDID. Expected: console appears within ~10s of boot (poll); if black,
reflash `parameter.txt` (force mode) as the fallback.

**Write speed (user-measured, v17.2): 4.5 MB/s** sustained fsync (64MB and
16MB at the same speed), `ftl_write_error_count = 0`. Combined with 7.5–8.1
MB/s read — the internal storage is now genuinely usable.

fsck incident (Round 38→39): the no-journal rootfs picked up orphan inode 337
from hard power-offs during testing — fsck.ext4 -y at the initramfs
prompt fixed it. Recommendation for the user: `tune2fs -O has_journal -J size=32`
now that IO is ×10. Verify udelay patch safety: loop budget
`r4=100000` × ~1.5µs ≈ 150–250ms (vendor healthy ~200–400ms, real
ops ≤10ms — 20× headroom).

## Z.7 — Enabling the ext4 journal (HDMI finalized OK at native mode)

HDMI is complete (user accepted the native mode). Journal enabled in 2 tiers:

**Tier 1 — on the running box (no reflash):**
```
tune2fs -O has_journal -J size=32 /dev/rknand_root
dumpe2fs -h /dev/rknand_root | grep -i journal   # must show has_journal + 32M
```
If tune2fs refuses because the fs is mounted ("Cannot change has_journal on a
mounted filesystem" or similar): use **Tier 2**.

**Tier 2 — artifact with the journal already enabled:** `output/armbian_rootfs_v15j_xmio.img`
(sha256 `5457bc19e70a67762671fa1edbc8b7739d0d65dcc834aa11f71de7d3439337f7`,
md5 `f84615bd7879df1562dcef58571059e7`) — clean under e2fsck -fn, 32M journal,
matching the rootfs window. Flash with RKDevTool: file → `0x17000`. Note: it overwrites
the entire rootfs → every change made on the box (since the v15 flash) is lost, returning to
the image state (fsck fix + journal already in place).

Once the journal is working: power loss/hard-reset no longer causes orphan
inodes — the kernel replays the journal itself at mount. The fs should still
get a periodic fsck when convenient (`fsck.ext4 -f /dev/rknand_root` from initramfs).

## Z.8 — v18.2: enable I/O accounting (iotop works)

Rootfs image finalized at native mode + journal: the user chose Path A/B separately.
Kernel additions: `CONFIG_TASKSTATS=y TASK_DELAY_ACCT=y TASK_XACCT=y
TASK_IO_ACCOUNTING=y` — iotop/pidstat//proc/*/io work.
Kernel rebuild, DTB kept at v17.

**Flash 2 files:**
| File | Address | md5 |
|---|---|---|
| `planb-stock-uboot/boot.img` | `0xE000` | `67960509190f9f31583b7cb4e2a2e1eb` |
| `planb-stock-uboot/resource.img` | `0x6800` | `c1901e0b2fb6e9a80052647b4899be0e` |

After flash + reboot, if iotop still complains it is missing: `sysctl
kernel.task_delayacct=1` (task_delayacct is default off since 5.13+,
keep it across reboots via /etc/sysctl.d/). Overhead warning: leaving
it =1 long-term slightly increases scheduler cost; enable it when you need to inspect IO.

Investigating background IO (user report: idle but IO still running):
`for p in /proc/[0-9]*; do [ -r $p/io ] && grep -H read_bytes $p/io; done |
 sort -t: -k2 -n | tail -8` — with TASK_IO_ACCOUNTING=1 this shows the process
doing the heavy reads (suspect journald/chronyd/fsck-daemon); if after v18.2
no suspects remain → normal background rhythm (log/journal auto
fsync), no action needed.

## Z.9 — v19.1: Status LEDs (GPIO scan + DTB + service)

**GPIO LEDs (from on-device probing):** red/green dual LED @ **gpio0_B0**
(sysfs 8, anti-parallel: pin HIGH = red, LOW = green), yellow @
**gpio1_B1** (sysfs 41). No LED nodes in the stock DTB — XMIO
manages the GPIOs outside the DT.

**v19 kernel** (LEDS_TRIGGER_HEARTBEAT=y): boot.img md5
`d9b7bb3bb16d4cff47bb73dffe369825` @`0xE000` (with the LED DTB bundled inside).
**v19.1 DTB** (xmio-leds node: status-led default-state=on +
heartbeat; io-led default-state=off): resource.img md5
`a032aeaf8c1e1d83f1e927196d7c21d0` @`0x6800`.

Behavior: power applied ~1-2s → heartbeat blinking (red with green interleaved, because pin
low = green — a single-pin dual LED has no off state via the led class).
Service `/usr/local/bin/xmio-led` (systemd xmio-led.service,
multi-user) takes ownership: trigger none; no network = red (brightness 1),
network up = green (0); yellow blinks on the delta of `/proc/diskstats`
rknand_root ($6/$10 sectors) loop 0.5s.

On-box installer: `output/planb-stock-uboot/onbox/` (xmio-led,
xmio-led.service). If red/green are swapped on real hardware → change the 2 lines
`echo 0/1 > brightness` in the service (no rebuild needed).
Internal FTL GC does NOT show on the yellow LED (it does not go through the block layer).

## Z.10 — v19.2: yellow ACTIVE_LOW + instantly responsive service

Real hardware: yellow **lights up inverted** (reverse-polarity wiring) → DTB flag
`GPIO_ACTIVE_LOW` for io-led (the kernel inverts it, the service keeps the logic
1 = IO present). Red/green was slow due to the old unit `Wants=network-online.target`
(waits for DHCP) → dropped, the service starts right after multi-user; network detection switched
to `carrier` (cable plugged=1, instant) + operstate; loop 0.5s→0.3s.
boot.img `c8d5e478a813a45e75f55f469f2cc122` @`0xE000`, resource.img
`08f99cd17bd8bb76937a0adbea868169` @`0x6800`. New service files in
onbox/ (reinstall the 2 files: xmio-led + xmio-led.service, enable --now).

## Z.11 — v21/v19.4-stock: STOCK MODE — LEDs via kernel triggers + armbian-led-state

Chose the "no daemon" approach: all LED behavior belongs to kernel triggers
(`heartbeat` boot, `netdev` network) + `armbian-led-state.service`
(save/restore of configuration via /etc/armbian-leds.conf). Kernel v21 adds
`CONFIG_LEDS_TRIGGER_NETDEV=y`. DTB v19.4: status-led **ACTIVE_LOW**
(flag 0x01 — polarity flip: pin LOW = lit → "on" = GREEN, "off" = RED),
`default-trigger = "heartbeat"` (boot: red blinking 90% of each cycle, no
more "stuck green" race since the off-state is now RED), `default-state = "off"`.
**Accepted limitation**: yellow stays off permanently (no rknand hook in the
kernel); green = end0 carrier, does not distinguish IP/gateway.

Flash: boot.img `6d405bf6f5ece040bd470a62f19ff2d6` @`0xE000` +
resource.img `aff898ad7913fc76ea5afe9fc10c6ec0` @`0x6800` (a pair —
always flash them together). After flashing, on the box:

```sh
# daemon mode OFF, stock mode ON
systemctl disable --now xmio-led 2>/dev/null
rm -f /etc/armbian-leds.conf
systemctl enable --now armbian-led-state

# configure the netdev trigger for status-led (ONCE, save.sh persists it)
echo netdev > /sys/class/leds/xmio:red-green:status/trigger
echo end0   > /sys/class/leds/xmio:red-green:status/device_name
echo 1      > /sys/class/leds/xmio:red-green:status/link
echo 0      > /sys/class/leds/xmio:red-green:status/rx
echo 0      > /sys/class/leds/xmio:red-green:status/tx
```

Behavior: power on → RED blinking (heartbeat) throughout boot; entering Armbian →
armbian-led-state restores netdev → **GREEN when end0 has a cable**, RED when
no cable; unplugging/plugging the cable reacts in ~1s (netdev interval defaults to 50ms).
Verify: `cat /sys/class/leds/xmio:red-green:status/trigger`
(you must see `[netdev]`), `cat /etc/armbian-leds.conf` (the trigger
is saved). To bring yellow back to "life" at any time: go back to the daemon
(v20.2) — just enable xmio-led, no additional flashing needed.

## Z.12 — v22 rootfs: RAM-only logging (NAND wear prevention)

Base v15j (keeps the ext4 journal). Edits applied directly to the image (debugfs -w):

| Change | Reason |
|---|---|
| `/etc/systemd/journald.conf` + `Storage=volatile`, `RuntimeMaxUse=16M`, `SystemMaxUse=16M`, `Compress=no` | journald writes only to `/run` (RAM), at most 16M |
| delete `/var/log/journal` | hardening — no persistent location left |
| unlink `multi-user.target.wants/rsyslog.service` | rsyslog writes `/var/log/syslog`... to the NAND continuously |
| delete `/etc/cron.d/sysstat` + `cron.daily/sysstat` | sa1 writes every 10 minutes |
| `chrony.conf`: driftfile → `/run/chrony` + tmpfiles.d creates the dir | the driftfile overwrites the same NAND block every hour/per write |

Flash: rootfs @`0x17000` — `armbian_rootfs_v22_xmio.img`
md5 `04f91b9b017f6856f341a6273d04319b` (1,157,545,984 bytes).
Logs after every reboot will be LOST (inherent to RAM-only); to watch logs live:
`journalctl -f`, `journalctl -b`, `dmesg`.

After flashing, the stock-mode LED configuration is wiped along with it (it belongs to the rootfs) —
re-run the Z.11 block (echo netdev/device_name/link + power the box off once
so save.sh writes the conf). Kernel v21 + boot/resource do NOT need reflashing.

## Z.13 — v23: restoring the original MAC via vendor storage (LAN_MAC_ID)

Problem: the kernel uses the fallback MAC `02:31:28:16:01:28` hard-coded in
the DTB. The priority order of `of_get_mac_address()`: mac-address →
local-mac-address → nvmem — the DT has a valid value → stmmac **never
asks** vendor storage (where stock Android stores the real MAC via
U-Boot `ethaddr`).

Fix v23 (kernel + DTB):
1. `CONFIG_ROCKCHIP_VENDOR_STORAGE=y` — the `rk_vendor_read/write/
   register` core (backend already present: `rk_nand_blk.c` calls
   `rk_ftl_vendor_storage_init()` + `rk_vendor_register()` +
   creates `/dev/vendor_storage`).
2. DTB v23: **delete `local-mac-address`** → probe chain:
   `stmmac_check_ether_addr` → `rk_get_eth_addr` (dwmac-rk) →
   `rk_vendor_read(LAN_MAC_ID=3)` → the original MAC that Android recorded. If
   vendor is empty: generate a random one + **write it into vendor storage** →
   stable on every subsequent boot (no further changes).

Flash the pair:
- boot.img `7c5db45984a326c735cc3a51f1e7c6e6` @`0xE000`
- resource.img `832b79f3f0cc3399eaa2a35af0b18582` @`0x6800`

Verify after flashing (dmesg):
```
rknand vendor storage init ok !
rk_get_eth_addr: mac address: xx:xx:xx:xx:xx:xx   ← real MAC
```
`ip link show end0` → compare the MAC against what Android stock used to show
(or the box label). `/dev/vendor_storage` exists = the backend is alive.

Rollback to v21: reflash the old pair (`6d405bf6…`/`aff898ad…`).

## Z.14 — v23.2: label-sticker MAC via DTB (end of the MAC arc)

Evidence of the MAC's provenance:
- Efuse dump (32B on the box): only the magic `52 4b` + 16B chip ID
  (offset 7) + leakage — **no MAC is burned into the efuse**.
- Stock Android kernel: `Read the Ethernet MAC address from
  IDB:00:00:00:00:00:00` — the IDB is also **empty from the factory**, not
  wiped away by reflashing.
- The A26 kernel has no code to read the MAC from the IDB (the string doesn't exist);
  the FTL blob only has an IDB read API (`FlashReadIdbData`), no write.

→ The label sticker `B8:3D:4E:84:3D:A3` (global OUI, U/L bit=0) is the only
original identity. v23.2 assigns it to the gmac's `local-mac-address`
in the DTB — stored in boot.img + resource.img = **persistent in
flash**, not random, survives every rootfs reflash.

Flash the pair:
- boot.img `85be3b158d79591b3fa68e1890900488` @`0xE000`
- resource.img `f849f2e6de3bc7a117b6346cd09fe326` @`0x6800`

Verify: `ip link show end0` → `B8:3D:4E:84:3D:A3`. dmesg **no
longer** has the `rk_get_eth_addr` line (the DT MAC preempts the vendor path); the
remaining `rknand vendor storage init failed !` line is cosmetic, harmless.

## Z.15 — v23.3: persist the MAC into the U-Boot default env (survives
## every other firmware flash)

The remaining problem of Z.14: `local-mac-address` lives in boot.img/
resource.img — flashing different firmware overwrites it. Solution: stuff
`ethaddr=B8:3D:4E:84:3D:A3` into the **default environment** inside
the stock U-Boot binary (`uboot@0x2000`). U-Boot already ships
`fdt_fixup_ethernet()` (proof: the strings `local-mac-address`,
`eth%daddr` in the image) — before booting the kernel, it **writes the MAC from
the env into the DTB's ethernet node no matter which firmware that DTB comes from**.
=> the MAC lives at the lowest layer, belonging to neither boot/resource/rootfs,
lost only if someone deliberately reflashes the uboot partition.

Technique: the stock U-Boot default env string-table sits at offset
0x3b1c9 (`bootdelay=0\0baudrate=115200\0preboot=\0verify=n\0
initrd_high=0xffffffff=n\0`) — 73 bytes of slack up to rodata. Drop
bootdelay/preboot/verify (unused by bootrk), insert
`ethaddr=...` (26B) + keep baudrate + initrd_high (byte-exact with its
`=n` quirk) = 67B. The image has 2 identical 512K mirrors → patch
both. File: `tools/v23.3-uboot-mac.py` (strict verification: mirrors
in sync, MAC 2/2, bootdelay gone).

Flash (replace uboot):
- uboot-planb-mac.img
  sha256 `5e45a5afab9593433beadf17281e6ff0a62bb1ecb8db201ad40ba2ccbb895d6d`
  @`0x2000` (uboot partition — write with the usual flash tool,
  same path and offsets as the previous uboot flashes).
- NO need to flash boot/resource/rootfs — but if flashing the whole set,
  the safe order: miniloader → uboot-planb-mac → (boot+resource
  v23.2 if you want the MAC in the DTB too) → rootfs.

Verify after flashing:
```
# UART during U-Boot boot:
printenv           # shows ethaddr=B8:3D:4E:84:3D:A3
# or in Linux:
ip link show end0  # B8:3D:4E:84:3D:A3
```

Rollback: reflash `uboot-stock.img` @0x2000.

## Z.16 — v24: write the MAC into vendor storage (the deepest flash layer)

Vendor storage is a data region managed by the NAND FTL (4 slots × 128
reserved blocks, OUTSIDE every partition — parameter.txt never sees it,
no firmware flash ever touches it). Kernel 6.6 (dwmac-rk) and
A26 U-Boot (board.c:122) both read `LAN_MAC_ID=3` from here. This box
has never had its vendor region initialized (the 2016 factory used the IDB, wiped
away by the full-firmware upgrades) — v24 enables **initializing it and writing the MAC**
from userspace.

Components:
- boot.img v24: a one-line kernel patch — `/dev/vendor_storage` is always
  registered even when the vendor area scan fails (so userspace can
  write to it the first time).
- `onbox/vendor-mac` (static ARM, md5 `5e9092e017d6097b76a09a1f321e7b30`):
  a tool that writes LAN_MAC_ID = B8:3D:4E:84:3D:A3 via the standard
  RK_VENDOR_REQ ioctl (read → write → read-back verify). Optional arg:
  a different MAC.

### Procedure

1. Flash boot.img v24 `a0aaa1ca576783c877bf89ceede98287` @`0xE000`
   (resource stays at v23.2 — the file is unchanged).
2. Boot, copy the tool over the LAN from Windows (PowerShell):
   ```
   scp output/planb-stock-uboot/onbox/vendor-mac root@<IP-box>:/tmp/
   ```
3. On the box:
   ```
   chmod +x /tmp/vendor-mac
   /tmp/vendor-mac
   ```
4. Result:
   - `verify OK: ... stored in vendor storage` → the MAC is now in
     flash at the FTL-reserved layer. From now on: any firmware can
     be flashed (including a different uboot) — both kernel 6.6 A26 and U-Boot A26
     read LAN_MAC_ID on their own. (If that firmware hard-assigns
     local-mac-address in its DTB, the DTB wins — adjust/remove per that firmware.)
   - `VENDOR_WRITE_IO: ...` error / verify FAILED → the blob refuses
     format-on-write → use the v23.3 approach (uboot env, Z.15).

### After a successful write — durability test

**Z.16.1 — CONFIRMED (tested on the box)**: write once with the tool on
v24 → flash boot-v23 (different kernel) → `vendor storage init ok !` for the
first time in the box's history → back to v24 → the tool reads
`b8:3d:4e:84:3d:a3` back from flash. Real persistence, surviving
boot image changes.

## Z.17 — v24.1: MAC ENTIRELY from vendor storage (no hardcoding)

User decision: drop `local-mac-address` from the DTB — a hardcoded MAC
belongs to the IMAGE, not to the DEVICE; flashing the image to another box
makes that box wrongly take the old box's MAC. Vendor storage is per-device
→ boot.img can be copied freely between boxes.

v24.1 changes:
1. DTB v23: NO local-mac-address (resource.img goes back to
   `832b79f3f0cc3399eaa2a35af0b18582` — exactly identical to v23).
2. dwmac-rk patch: gmac probe **defers** (`-EPROBE_DEFER`, up to 64
   times) when the DTB has no MAC AND the vendor backend is not ready yet.
   nand init finishes (~5.5s) → re-probe → reads `LAN_MAC_ID=3` → correct MAC
   before NetworkManager brings the interface up (~17s).
3. Fallback: 64 defers without seeing the vendor (a new box that has never had a
   MAC written) → random as before — never lose the network permanently. Write
   the MAC with `vendor-mac` then reboot and it is there.
4. `uboot-planb-mac.img` (Z.15) **DEPRECATED** — the env MAC is also
   a per-image hardcode (same multi-box problem). Kept only as a
   reference rollback.

Flash:
- boot.img `6e4aeb493842372eea83bbcefb55b9f3` @`0xE000`
- resource.img `832b79f3f0cc3399eaa2a35af0b18582` @`0x6800`

Verify after flashing:
```
dmesg | grep -E 'rk_get_eth_addr|vendor storage init|device MAC'
#  expected: init ok ! + mac address: b8:3d:4e:84:3d:a3
ip link show end0                     # B8:3D:4E:84:3D:A3
```
A DIFFERENT box (MAC not yet written): boots normally (random after 64 defers) →
run vendor-mac <MAC-of-that-box> → reboot → its own correct MAC.

MAC-in-DTB rollback: flash `resource.img.v23.2-mac.bak` @`0x6800`.

## Z.18 — v24.2: /proc/cpuinfo correct (Hardware + Serial per-device)

Final diagnosis (verified by decompiling the shipped DTB):
- `model name ARMv7...` = correct by arm32 design (CORE name from
  MIDR; RK3128 = 4× Cortex-A7 rev 5) — nothing to fix.
- The `cpuinfo` node (compatible "rockchip,cpuinfo", nvmem-cells →
  efuse id@7) **has been in the DTB since v23** (inherited from stock A26)
  → the driver probe had already run; dmesg already had the line
  `rockchip-cpuinfo cpuinfo: Serial : XXXXXXXX`.
- `Serial: 0000000000000000` in /proc/cpuinfo: setup.c kasprintfs
  the serial string TOO EARLY (crc32 not yet computed = 0) and caches it; the driver sets
  system_serial_low/high afterwards but /proc reads the old string. v24.2 fix:
  the driver overwrites the string after computing the crc32.
- `Hardware: Generic DT based system`: mach-rockchip's dt_compat
  lacks rk3128 → v24.2 adds `"rockchip,rk3128"` → it is now
  `Rockchip (Device Tree)`.
- `initcall_blacklist=rockchip_cpuinfo_init` in the kernel parameters:
  no-op on kernel 6.6 (the function doesn't exist) — harmless, left as is.

The new Serial = crc32 of the 16-byte efuse chip-ID (OTP) → **one unique
serial per box, nothing hardcoded into the image** — same vendor-only philosophy
as the MAC.

Flash: ONLY boot.img @`0xE000` — `468c5d940187bfbd6cfd9dd6abc55171`.
resource.img md5 `832b79f3…` UNCHANGED (the cpuinfo node was already
in the DTB) → no need to flash resource.

Verify after flashing:
```
grep -E 'Hardware|Serial' /proc/cpuinfo
#  Hardware        : Rockchip (Device Tree)
#  Serial          : XXXXXXXXXXXXXXXX  (non-zero, stable across reboots)
dmesg | grep -i cpuinfo               # SoC + Serial line
ip link show end0                     # MAC still B8:... (vendor)
```

## Z.19 — v24.3b: LED via armbian-led-state (standard Armbian, no separate script)

User settled on: use the built-in **armbian-led-state**, NOT xmio-led-green,
NO kernel changes. (v24.3b replaces the rootfs part of the original Z.19.)

### Stock mechanism verified by dissecting the scripts in the rootfs

- `armbian-led-state.service` **already enabled by stock** under
  `basic.target.wants` (ExecStart=restore, ExecStop=save).
- save.sh (at shutdown): writes `/etc/armbian-leds.conf` — **all
  writable parameters of each LED** (trigger, device_name, link, rx,
  tx of netdev…), except brightness when the trigger is `*:link`.
- restore.sh (at boot): writes it all back in the same order → the wlan0
  config **persists across reboots**, even after manual user edits.

### v23 rootfs contents (modified)

1. **Completely remove** xmio-led-green (script + unit + sysinit symlink).
2. **Pre-seed** `/etc/armbian-leds.conf`:
   - `xmio:red-green:status`: `trigger=none`, `brightness=1` → green lit
   - `xmio:yellow:io`: `trigger=netdev`, `device_name=wlan0`,
     `link=1`, `rx=1`, `tx=1` → yellow following wlan0
3. Stock unit/scripts kept fully intact.

DTB v24.3 (resource) keeps `default-state = "on"` for green → green LED
lit right from ~2s, even before restore runs (~10-15s). Kernel unchanged.

### Flash

| File | Offset | MD5 |
|---|---|---|
| boot.img | `0xE000` | `5f61edcd0d8477a7f899dea0a30baa68` |
| resource.img | `0x6800` | `b12893c9a630ee32304c4c3386760580` |
| **armbian_rootfs_v23_xmio.img** (build 3a9abd13) | `0x17000` | `3a9abd13ba954bc6912b90d67cc9e8a0` |

⚠️ If you already flashed rootfs v23 md5 `485fb7d6…` (the xmio-led-green build) →
overwrite-flash it with this `3a9abd13…` build. boot/resource need not be flashed again.

### Verify after flash

```
cat /etc/armbian-leds.conf                       # conf as above
cat /sys/class/leds/xmio:red-green:status/trigger    # [none], brightness=1
cat /sys/class/leds/xmio:yellow:io/trigger           # [netdev]
cat /sys/class/leds/xmio:yellow:io/device_name       # wlan0
shutdown -h now  → reboot → conf persists (save/restore loop)
```

Interface change: edit `/etc/armbian-leds.conf` (or adjust the trigger directly
and then shut down properly once — the save updates the conf itself).
Rootfs rollback: v22 (`04f91b9b…`).

## Z.22 — v2 still dead → IDB-loader theory; TEST C/D plan

### v2 test result (flash @0x2000, loader V2.25): does NOT boot
→ Rules out the "eMMC patch 218938c" theory (v2 does not contain that patch).

### Definitive correction: Loader tab EraseFlash+Download WRITES the loader into IDB
- Section B has always specified loader = `rk3128_loader_v2.12.263.bin`
  — because every flash following that procedure writes this loader into IDB.
- For the v1/v2 tests the loader used was `MiniLoaderAll(L)_V2.25_ink.bin`
  (stock) → **IDB switched to V2.25**.
- Comparing loader generations (build-year header field): V2.25 = **2015-era**
  (born for the 2014 stock uboot, flag 0x14, 302KB payload/512K
  mirror); v2.12.263 = **2026-era** (ships with A26, can read the
  2017-format uboot flag 0x20, payload ~839KB — proof: A26 boots OK).

### Behavior matrix — every cell matches the loader theory
| IDB loader | uboot @0x2000 | Result |
|---|---|---|
| v2.12.263 | stock 2014 (0x14) | ✅ boot (whole project, many months) |
| v2.12.263 | A26 2017 (0x20) | ✅ boot (first A26 test — network+DHCP) |
| **V2.25 (stock)** | stock 2014 (0x14) | ✅ boot (rollback after the test) |
| **V2.25 (stock)** | v1 2017 (0x20) | ❌ dead |
| **V2.25 (stock)** | v2 2017 (0x20) | ❌ dead |

V2.25 has NEVER been proven able to load a 2017-format uboot. Both
plausible mechanisms: (a) reads only a 512K window (mirror era), so the
836KB payload gets cut → CRC fail → dead; (b) doesn't recognize flag 0x20.

### Is hardware the cause? — NO (for the dead-boot symptom)
- The v2 embedded DTB ≡ the A26 DTB (already booted on this very box) — byte for byte.
- The UART is silent on A26 TOO: the uboot console = UART1 (0x20064000), the box
  pads are likely UART2 (shared with SDMMC, where the kernel prints its log). A26
  is silent on UART yet boots — proving silent UART ≠ dead.
- Buttons: the code reads ADC ch1 with threshold ≤30 tuned to the AUTHOR's
  board (commit 62a6711e48), not yet matching XMIO — affects A26 and v2 alike.

### TEST C — the decisive one (do first)
1. Loader tab: `rk3128_loader_v2.12.263.bin` → EraseFlash + Download
   (writes v2.12.263 into IDB).
2. Download Image: **only** `output/planb-uboot-v2/uboot-v2.img` @
   `0x00002000`.
3. Expected if the theory is right: network lights up + DHCP (as in the A26 run).
4. Rollback: `uboot-stock.img` @ `0x2000` (v2.12.263 lives happily with
   the stock uboot — proven across the whole project).

### TEST D — if C still dies
Flash `output/nand-flash/uboot.img` (true A26, `9c070f6e…`) @
`0x2000`, loader v2.12.263, keeping the native layout:
- It lives → the A26 binary runs on native; the only suspect left is the author's
  3KB "-dirty" local diff (not in git) → ask the author or stop.
- It dies → A26 only lives on the A26 layout (trust@0x4000 + its own flow) →
  stop: keep the stock uboot permanently, conclude "the 2017 uboot cannot run
  on this box's native layout".

### After every test — restore the working chain
Loader tab v2.12.263 (or leave it as is) + flash `uboot-stock.img`
`0c9788a3…` @ `0x2000` → the box is back on the exact v24.x chain as before.

## Z.23 — uboot-v3: real XMIO compatibility (UART2 console + channel-2 button)

### Essence: 4 patches on base 53cd91b73c (12 DTS lines + 1 const + defconfig)
| # | Patch | Reason |
|---|---|---|
| 1 | `CONFIG_DEBUG_UART_BASE=0x20068000` (uart2) | The author ALREADY wrote a uart2 branch in `board_debug_uart_init` (rk3128.c) with the comment "...for uart2 **and that is the most important part**". He uses UART1 for HIS box; the XMIO pads = UART2 (console stranded on UART1 → silent, like A26) |
| 2 | `&uart2 status okay` + `chosen stdout-path = "serial2:115200n8"` | The post-reloc console follows stdout-path |
| 3 | `&sdmmc + &emmc status disabled` | The XMIO has no eMMC; SD exists (works in stock Android) but is not a boot medium here — **GPIO1C2/C3 are pins SHARED between sdmmc_bus1(func1)/uart2_xfer(func2)** — an SD probe would flip the pinmux and kill the console → must be disabled |
| 4 | `RK3128_MASKROM_ADC_CH 1→2` | The XMIO button is on SARADC **channel 2** (kernel DTS adc-keys): VolUp≈0V, VolDown≈1.65V, home≈2.33V, back≈2.93V; threshold ≤30 (raw) = Volume Up |

- Verify the DTB after build: serial2 okay ✓, chosen serial2 ✓, sdmmc/emmc
  disabled ✓, saradc okay (from the reset-button commit) ✓.
- Banner: `U-Boot 2017.09-g53cd91b73c-250620-dirty` (dirty = our
  own patches, normal). Payload 836.072B.

### Files
| File | MD5 |
|---|---|
| `output/planb-uboot-v3/uboot-v3.img` (4MiB) | `7020d58236682be35396d6e8f7bd7a12` |
| `u-boot-v3.bin` (836.072B) | `1c7849304a0a1547e02a7eb45df3df1e` |
| `u-boot-v3.dtb` | `f72bc1e751bd250967fd43f9367a6cb3` |

### T1 — flash v3: FIRST TIME the pads match the console correctly
1. Loader tab: `rk3128_loader_v2.12.263.bin` → EraseFlash + Download.
2. Download Image: **only** `uboot-v3.img` @ `0x00002000`.
3. Plug the USB-TTL into UART2 (the kernel console) at 115200.
4. hold the key for 10s from power-on if you want to try MaskROM (channel 2,
   ~0V — most likely a Volume-Up-type key; if the box's loader key
   is a different button the threshold needs retuning per 2.33V/1.65V/2.93V).
This time the result is DIRECTLY READABLE: banner + errors (if any). Still
completely silent → the uboot truly isn't running (remaining: the author's
3KB "-dirty" or another anomaly) → stop, keep stock.

## Z.24 — v3 silent → all environmental variables eliminated; v4 = the author's toolchain

### T1 result (v3, loader v2.12.263 — user confirmed): completely silent
→ The death point is BEFORE the banner (pre-relocation, or the miniloader doesn't
jump). By this point ALL evidence eliminated: wrong console pin (v3 has the
right UART2, .config verify ✓), DTB (≡A26 except 12 deliberate lines),
loader version (263 — the generation proven with A26), eMMC patch
(v2 doesn't have it), defconfig (verify ✓), partition/format (header math ✓).

### The last two suspects — both in the binary
1. **Toolchain**: all of v1/v2/v3 built with gcc-arm-10.3; the only
   binary EVER known to live (A26) was built with gcc-linaro-6.3.1-2017.05
   (make.sh declares: CROSS_COMPILE_ARM32=...linaro-6.3.1...). Ancient
   U-Boot 2017 + modern GCC = textbook early-crash.
2. **"-dirty" ~3KB**: uncommitted local changes by the author at the
   time of the A26 build (banner confirms -dirty) — NOT in git.

### uboot-v4 = v3 patches + the author's EXACT toolchain (linaro 6.3.1)
- Toolchain: gitlab.com/firefly-linux/prebuilts (official mirror,
  `arm-linux-gnueabihf-gcc (Linaro GCC 6.3-2017.05) 6.3.1`), installed
  in /vol/toolchain-linaro (releases.linaro.org link is dead).
- Build: tools/uboot-v4-build2.sh (v3 worktree already patched, O=v4-build).
- Banner: `U-Boot 2017.09-g53cd91b73c-250620-dirty`.

| File | MD5 |
|---|---|
| `output/planb-uboot-v4/uboot-v4.img` (4MiB) | `5310987721e4ea25ddbe0e989b7ed1ed` |
| `u-boot-v4.bin` | `d7d6375e550fa405f603e1ff2df33234` |

### T2 — flash v4 (procedure identical to T1)
Loader tab `rk3128_loader_v2.12.263.bin` (EraseFlash+Download) →
flash **only** `uboot-v4.img` @ `0x00002000` → UART2 115200.
- Banner appears → conclude: toolchain was the culprit for all of v1/v2/v3 → keep
  debugging the boot path on a live console.
- Still silent → only the 3KB "-dirty" remains → only path: ask the author
  (draft ready: `output/planb-uboot-v4/AUTHOR-REQUEST-draft.md`).
- At any time: rollback = `uboot-stock.img` @ `0x2000`.

## Z.25 — VERDICT: flashing the author's full build also only blinks the LED → stop; v5 = the final note

### T2b result (done by the user): loader 263 + v4 + A26 param + trust +
root ta → network LED LIT + BLINKING, no UART/keys/DHCP/armbian.
THE SURPRISE: re-flashing the author's ENTIRE original build → exactly the same
(blinking LED, no DHCP). This inverts how the whole experiment chain reads:
- It was previously assumed that A26 once booting with DHCP = proof of a live binary —
  but that event happened MONTHS BEFORE the flash sequence in section B;
  the NAND/FTL/IDB state has since changed. Every post-T1 step has a reliable
  control "LED on = reached a later stage" — definitely usable.
- The problem scope shrinks: it is NO LONGER "our build is wrong" — it is
  "the recovery path for the current flash state". The 2017 binary never had
  a chance to run, even the author's own.

### Evidence table after downgrading A26 to "blinking LED"
| Control | Evidence |
|---|---|
| flash integrity | stock @0x2000 rollback always boots ✓; update.img contains the identical 2017 uboot that was originally flashed with the same RKDevTool ✓ |
| FTL/partitions | swapping files in the download list does NOT change behavior (v→ identical before/after); every self-built stock file boots ✓ |
| IDB loader 263 | flashed via Loader mode; both update.img and A26 use it ✓ |
| DRAM (263) | the 263 miniloader ran DDR init far enough to wait for the Loader ✓ |
| trust/param | complete since T2b — still blinking LED ✓ |
| MiniLoader V2.25 | likewise: enough to enter Loader mode ✓ |
| KLU | wires fully soldered, cable tested with another COM ✓ |

The remaining suspect (closed): older than the miniloader or between the two stages —
not testable by flashing.

### v5 — final note: every software suspect eliminated; key threshold ≤1000
linaro 6.3.1 + uart2 + adc-ch2 + ADC_MAX=1000 (every XMIO key
0–911 raw triggers; release = 1023). Payload 839.016B (~= A26 839.104,
linaro codegen matches the author's). `output/planb-uboot-v5/`:
uboot-v5.img `09461a8202a982e0a698c92529c1b554`.

### T3 — final test (if still wanting to settle it)
1. RESTORE FIRST: Loader 263 → flash **native parameter** +
   `misc.img` + `baseparamer-720P.img` + `resource.img` + `boot.img`
   + `rootfs v24.x` + `uboot-stock.img @0x2000` (all available;
   no need to reflash rootfs — trust-img only overwrites misc @0x4000..0x5FFF).
   Confirm SSH/DHCP alive.
2. Loader 263 → only `uboot-v5.img` @ `0x2000` → power on:
   - LED BLINKING → uboot actually runs; hold any KEY during the 9s bootdelay →
     if you see behavior (it gets stuck again = the key is read) → half success;
     UART2 silent → the 2017 BSP is hardware-atypical on this PCB → STOP.
   - LED NOT LIT → identical to every 2017 binary since v1 → STOP.
3. STOP = permanently restore stock uboot @0x2000; close the
   experiment file; keep: the v24.x chain, z24.25 matrix, AUTHOR-REQUEST (if
   you want to ask later), all v1–v5 artifacts in output/.

## Z.26 — FINAL VERDICT: T3 = LED OFF → UBOOT ARC CLOSED

### T3 result (clean native base + v5): NO network LED, keys unresponsive
→ The "LED OFF" branch — identical to every 2017 binary (v1/v2/v3/v4/v5).
The final picture of the whole arc:

| Configuration | Result |
|---|---|
| stock 2014 + native (any loader) | ✅ alive — the only one |
| any 2017 binary + native | ❌ LED off, no keys |
| author's A26 + A26 layout + trust (T2b) | ⚠️ blinking LED — the only sign of life from the 2017 generation, but no DHCP/UART/keys |
| author's A26 (first time, months ago) | ✅ once got DHCP — on the older flash/IDB state, not reproducible |

### Verdict
The wall sits at a layer older than the miniloader or between the two stages — CANNOT
be reached by flashing from outside. Every software suspect eliminated
(console/DTB/loader/toolchain/trust/param/format — Z.20–Z.25).
No UART output of any kind from the 2017 generation on this box → debugging
from inside is impossible from outside.

### Final state of the box — RESTORE 1 FILE
Flash `uboot-stock.img` `0c9788a3…` @ `0x00002000` (loader 263,
familiar procedure) → the v24.x chain works again exactly as before
this arc (DHCP/SSH/LED/cpuinfo unchanged).

### Legacy (kept)
- `output/planb-uboot-v1..v5/` — binaries + configs + full logs.
- `output/planb-uboot-v4/AUTHOR-REQUEST-draft.md` — if you later
  want to ask the author (English + Vietnamese, copy-paste ready).
- `/vol/toolchain-linaro` (6.3.1), repo unshallowed, all scripts
  `tools/uboot-*` — reproducing everything takes only minutes if new facts appear.
- Lessons recorded in NOTES §80–§86: role of the IDB loader, pinmux
  shared between UART2/sdmmc, ADC-key binding, limits of flash experiments.

## Z.21 — uboot-v2: rebuild from the EXACT base commit of A26 (53cd91b73c)

### v1 test result (Z.20) — flash @0x2000: does NOT boot
- No UART, no keys, no network. **A26 once booted OK on this very
  box** (network LED lit + DHCP offered) → the factory loader V2.25 in
  IDB CAN load the 2017-format uboot → the loader suspect is RULED OUT.
- Investigation after unshallowing the repo (54,864 commits): the v1 banner
  `2017.09-g218938c` = HEAD = base-A26 **+ commit 218938c** "Ad
  support for eMMC device as boot device" (+313/-5: storage_rk3128.c
  new, 196 lines; changes to dw_mmc/nand/rknand/boot flow). New suspect:
  this eMMC patch changes the boot flow before the NAND boot gets a chance to run.
- Correction from the user (verified against the actual commit): **the hardware button belongs to
  uboot** — commit `62a6711e48` "Add support for reset button:
  Holding will boot into Maskrom mode" (board file + saradc enabled
  in the DTS, 305 lines). Both A26 and v1/v2 HAVE this feature.
- v1 embedded DTB ≡ A26 embedded DTB (diff IDENTICAL, including the uart1 pinmux
  GPIO1_A9/A10 matching XMIO, stdout-path serial1@20064000).

### uboot-v2 = commit 53cd91b73c pristine (NO eMMC patch)
- Build: `tools/uboot-v2-build.sh` (git worktree @53cd91b73c + gcc
  10.3, out-of-tree /vol/uboot-a26-build). Banner:
  `U-Boot 2017.09-g53cd91b73c-250620` — **same hash+date as A26**,
  only missing `-dirty` (the A26 build had small local changes, uncommitted).
- Payload 836,088 B (A26: 839,104 — a ~3KB gap = exactly the dirty part).
- Artifacts: `output/planb-uboot-v2/` — uboot-v2.img
  `ca01587010375dff4e951848e3bd6bb4` (4MiB), u-boot-v2.bin
  `9e79d7e7…`, uboot-v2.config `599aed86…` (same defconfig as v1),
  build.log, MD5SUMS.

### Flash test v2 — conditions identical to Plan B Z.20
1. Loader tab: load `rk3128MiniLoaderAll(L)_V2.25_ink.bin`.
2. Download Image: **only** `uboot-v2.img` @ `0x00002000`.
3. Expected on UART1 115200: banner `U-Boot 2017.09-g53cd91b73c-250620`
   + prompt `RK3128 >>`, bootdelay 9s; holding the reset button for 10s → MaskROM
   (reset-button commit); bootrkp → boot.img v24.x as usual.
4. Rollback: `uboot-stock.img` `0c9788a3…` @ `0x2000`.

### The proof matrix is gradually closing in
| Build | Base commit | eMMC patch | Status |
|---|---|---|---|
| A26 (author's) | 53cd91b73c | no | ✅ has booted OK on the box before |
| uboot-v1 | 218938c (HEAD) | **yes** | ❌ dead, no log |
| uboot-v2 | 53cd91b73c | no | ⏳ awaiting test — if it still dies → the cause lies in the author's local "-dirty" changes or some other variable |

If v2 boots OK → conclusion: the v1 cause = the eMMC patch (218938c) breaking
NAND-first boot on the box without eMMC; v2 becomes the standard uboot
rebuild, usable as a base for later upgrades (enable the DM key after adding the node).

## Z.20 — uboot-v1: rebuild U-Boot from source (build OK; flash-test FAIL)

> ⚠️ The v1 test result = does NOT boot (no log/button/network) — investigation +
> cause + the v2 build: see **Z.21**. Two statements in this section were
> CORRECTED (marked [CORRECTED]): "loader v2.12.263 is mandatory" and "the hardware button
> belongs to the ROM/loader" — in fact: A26 boots OK with the factory V2.25 loader
> in IDB (the loader in the flash session is only used to load files and does not affect
> boot); the hardware button belongs to uboot (commit 62a6711e48 in the tree).

It started from the question "without the manufacturer's SDK, can a proper
uboot be built?". Answer: **YES — built successfully**, because the
U-Boot source of the A26 build itself is right there in the workspace
(`repos/u-boot-rk3128-tvbox`):
- A26 banner: `U-Boot 2017.09-g53cd91b73c-250620-dirty` = the commit
  right before `218938c` in this repo → the genuine upstream source.
- `arch/arm/mach-rockchip/board.c:122` reads `vendor_storage_read(
  LAN_MAC_ID)` — exactly the spot NOTES documented (self-read MAC kept as is).
- Clean build with gcc-arm-10.3, NO SDK needed. Features verified via
  the final build `.config`: RKNAND (NAND boot), RKPARM, ADC/GPIO/DM/RK
  key (hardware button+recovery), DEBUG_UART UART1 0x20064000 (uart—
  same as A26), Android boot (`boot_android`→`bootrkp`→distro_bootcmd),
  vendor partition, fastboot, MMC, OPTEE.

### Files (built, NOT flashed — your decision)

| File | MD5 | Notes |
|---|---|---|
| `output/planb-uboot-v1/uboot-v1.img` | `d87d27629ea5ad6fc9c540ab2e0e8e7d` | 4MiB pack (loaderimage, load addr 0x60000000) |
| `output/planb-uboot-v1/u-boot-v1.bin` | `ccbcaeaa37f3c39ec2f4685d5e4ade83` | raw u-boot.bin 816KB (cross-check A26 payload 839104B) |
| `output/planb-uboot-v1/uboot-v1.config` | `599aed869ad463bb2358c65bb954b783` | final build .config |

Rebuild scripts: `tools/uboot-v1-build.sh`, `tools/uboot-v1-pack.sh`,
`tools/uboot-v1-featurecheck.sh` (checkpoint container: `/vol/uboot-src`,
`/vol/uboot-build`, rkbin `/vol/rkbin`).

### Partition size & format (dissecting the real header — tools/uboot-format-check.sh)

The uboot partition is **4MiB in both layouts**: `0x00002000@0x00002000(uboot)` =
0x2000 sectors × 512B = 4,194,304 B (both native and A26). The stock 1MiB file only
fills 1/4 of the partition; the 4MiB uboot-v1 file fills the partition EXACTLY, ending at
0x4000 — it does NOT touch misc (0x4000). All 3 files share the container format
"LOADER  " (magic + load-addr + size + CRC in the 2KB header) — the loader in IDB
reads size/addr FROM THE HEADER, independent of the file size:

| File | Load addr (header) | Payload size (header) | CRC | Flag |
|---|---|---|---|---|
| uboot-stock.img (1MiB) | 0x60200000 | 301,784 B | 0x5def9d05* | 0x14 |
| uboot.img A26 (4MiB) | 0x60000000 | 839,104 B | 0x9851ae49 | 0x20 |
| uboot-v1.img (4MiB) | 0x60000000 | 836,496 B | 0x7b49cab4 | 0x20 |

(*) The stock CRC is displayed in the file byte order `05 9d ef 5d`.
Stock = header + 302KB code + 512K pad, mirrored ×2 (protection against bad blocks);
A26/uboot-v1 = header + ~820-840KB code + 4MiB zero-pad (loaderimage).
Payload > 512K → load the Loader in the Loader tab (standard procedure, section B).
[CORRECTED a 2nd time — see Z.22] The Loader-tab Download DOES write the loader into IDB →
the loader version in IDB IS the real boot variable. The payload size
may still be part of the mechanism (V2.25 reads the 512K mirror), but the root
cause = the loader generation (the 2015-era V2.25 only survives with uboot flag
0x14; the 2026-era v2.12.263 can read both 0x14 and 0x20).
⚠️ The file flashed @0x2000 must NOT exceed 4MiB (it would overwrite misc @0x4000).
⚠️ Plan B does NOT flash trust.img (4MiB @0x4000 would overwrite the native misc).

### Flash (if you want to test) — Plan B "1-file uboot swap"

Leave UNTOUCHED: parameter (native), misc, boot.img, resource, rootfs.
Procedure from section B (load the Loader in the Loader tab — any loader file will
do, since it only serves the flash session and is not stored in IDB), then flash
**ONLY** `uboot-v1.img` @ `0x00002000` (flash no other file,
NO trust.img — it would overwrite misc @0x4000).
Rollback: flash `output/planb-stock-uboot/uboot-stock.img` again
(`0c9788a3a729178a1b2eeb15656450b2`) @ `0x2000`.
→ The box drops into MaskROM by holding reset + plugging in USB if the boot is broken
(the rescue path is always available, as with every previous flash).

Expected on UART1 115200: banner `U-Boot 2017.09-g218938c-dirty
(RK3128 >>)` + bootdelay 9s → bootrkp reads the native parameter → loads
boot.img v24.x just like the current chain.

⚠️ DO NOT flash uboot-v1 on the A26 layout (Trust @0x4000, root@0x6000,
no boot@0xE000) — there will be no boot partition for bootrkp to read.
The box's current layout is NATIVE (6 partitions); uboot-v1 was
built to be compatible with exactly this layout.

## Z.27 — v24.4: random MAC fallback + vendor-mac in rootfs (fixes "no eth0")

**Symptoms** (after reflashing the chain): kernel boots OK, console
alive, but `ip a` shows no eth0; dmesg repeats 3 gmac lines then
`platform 2008c000.ethernet: deferred probe pending`.

**Root cause**: the MAC patch v24 (Z.16) defers gmac waiting for vendor storage
ready; the 64-iteration exit counter NEVER trips because the deferred-probe core
6.6 stops retrying after `driver_deferred_probe_timeout` (~15s) — the old
patch = a bug. Session T2b used the Loader tab (EraseFlash) → wiped the NAND
CLEAN including the vendor area (outside every partition) → vendor dead permanently →
gmac defers forever. Every reflashed file is correct — not a file
bug; the vendor area cannot be reflashed with a partition image.

**Two-tier fix (v24.4 → v24.4c after on-box testing)**:
1. Kernel (`dwmac-rk.c`): replaced the counter-64 with a blocking wait
   then a random MAC fallback — eth0 ALWAYS comes up. On-box test round 1
   (cap 10s, boot `70d473d8…`): vendor init `ok` at 17.45s —
   2s PAST the cap → still random. The real RCA (round 4): the blocking wait
   in probe OCCUPIES the single-threaded deferred-probe thread → rk_nand
   (the vendor backend, sitting BEHIND gmac in the queue) starves — a race
   caused by the patch itself. v24.4c: **yield (-EPROBE_DEFER) like
   the old kernel + self-driven retry** (delayed work 2s + device_attach,
   30s deadline for a genuinely dead vendor) → boot.img
   `f1e3098968637e76a52b297804996590` @0xE000, zImage `e7ff8c59…`;
   v24.4b backup → `output/archive/boot-v24.4b.img`.
2. rootfs **v23.2** (`657da568d2a31ae1676eda78a63091b9` @0x17000,
   clean build from v23 — does NOT use debugfs write to overwrite an existing
   file, the "Ext2 file already exists" error): `vendor-mac` static ARM + mode
   `show`; `vendor-mac-apply` **waits up to 60s for the dwmac interface**
   before read/write/apply; unit `vendor-mac.service`
   @sysinit.target.wants; always exits 0.

**On-box proof round 1** (self-heal mechanism confirmed):
- Boot 1: gmac random (`02:f6:…`) → service writes vendor OK +
  sets live `b8:3d:4e:84:3d:a3` → DHCP `.4`. `vendor-mac` reads
  back OK = the ioctl path is alive, the area rebuilt itself after EraseFlash.
- Boot 2 (reboot): **`rknand vendor storage init ok !` at
  17.45s** = the vendor area PERSISTS across reboot (§72 replay).
- RCA round 4 (full record in NOTES §88): the blocking-wait is
  the CAUSE of the race (it occupies the single-threaded deferred-probe thread,
  starving rk_nand behind it) — v24.4c yield + self-retry settles the design.

**Flash**: (a) `boot.img` (v24.4c `f1e30989…`) @0xE000; (b) rootfs
v23.2 (`657da568…`) @0x17000 — flash both. Already on v24.4a/b +
v23.1: just flash boot v24.4c (the old service is still fine).

**Expected after flash**: eth0 comes up within ≤10s (random if the vendor is dead),
then `vendor-mac: IF: xx → b8:3d:4e:84:3d:a3 (live)`; dmesg shows
`rk_gmac: vendor storage not ready after 10000ms - using random MAC`;
if the vendor revives → boot shows `rknand vendor storage init ok !`
+ eth0 with the correct label MAC right from the kernel.

Rollback: boot v24.3 (`output/archive/boot-v24.3.img`), rootfs v23
(`3a9abd13…`).

## Z.28 — v24.4c-era black HDMI + force-mode cmdline fix (finalized 09/09)

**Symptoms**: HDMI does not come up (a completely black screen) even though the box
boots normally, and eth/LED/SSH work. Happens on boot v24.4c + rootfs v23.2.

**RCA (full details in NOTES §91–92)**: not a code regression — the kernel/
config/DTB/parameter are all identical to the HDMI-OK era (§48). Mechanism:
the native boot enables CRTC **1080p120@297MHz before fbdev runs**
(the rockchip show-logo path), and fbdev then **attaches no framebuffer**
to the plane → the VOP scans from `addr 0x00000000` → permanently black. Every
runtime modeset (modetest/hotplug) hits the HPD-glitch loop: TMDS on →
HPD glitch (+3 IRQ) → connector flap → fb_helper restores to
p120-addr-0 within ~250ms → always black. (Note: `/proc/fb` and
`/dev/fb0` not existing is NORMAL — `CONFIG_FB_DEVICE=n`
was already the case; fbcon still works via the internal fb_info.)

**Fix (final, for long-term use)**: force the mode via cmdline — the `video=`
mode wins every fb_helper restore; fb is attached from the start:

| File | Address | md5 |
|---|---|---|
| `planb-stock-uboot/parameter.txt.force` | `0x0` | `3bccabd1392a9e340d26922b68bb4aeb` |

Differs from parameter.txt by 1 token: `video=HDMI-A-1:1920x1080@60e` inserted
before `root=`. boot/rootfs/resource unchanged.

**Expected after flash**: the TV shows the Armbian console at 1080p60; dmesg has
`Update mode to 1920x1080p60` at ~3.4s. You may see one flip back
to p120 afterwards (HPD event) — harmless, the plane still holds the real
framebuffer (`summary` shows `buf addr: 0x007e9000`, pitch 7680) → the picture
is still alive. Black state = `buf addr: 0x00000000`.

**Observing the screen on the box** (debug path, SSH root@<box-ip>):
- `cat /sys/kernel/debug/dri/0/summary` — mode + `buf[0] addr`:
  addr ≠ 0 means alive, addr 0 means black.
  - Manual test pattern: `modetest -M rockchip -s 85@70:1920x1080-60@XR24`
  (apt install libdrm-tests; overridden by the HPD-flap after ~250ms but
  enough to inspect the pipeline).
  - EDID: `od -A x -t x1 /sys/class/drm/card0-HDMI-A-1/edid`.

Rollback to native (not recommended — reproduces the black screen):
flash `parameter.txt` (`ab7c5744…`) @0x0.

Future option (not done yet): cap inno_hdmi mode_valid at ≤165MHz
so native cannot pick p120 — the video= token could then be dropped from the cmdline.

## Z.29 — v27: cap inno mode_valid 165MHz (clean native build, NO video= needed)

Replaces the Z.28 fix. The root RCA is explicit (NOTES §93): `mode_valid` of
inno_hdmi accepts every mode while the RK3128 PHY table is only calibrated
up to 165MHz — every mode >165MHz (1080p120@297, 1440p60@241.5) runs the PHY
with garbage configuration (0x00/0x00) → a broken signal. Patch: `mode->clock >
165000 → MODE_CLOCK_HIGH`. The EDID fallback lands at 1080p60@148.5 (the
165MHz point in the table). The patch filters on every path (fbdev/atomic), running
before the VOP, so the native boot has no way left to pick a mode above the threshold.

**Flash 2 files:**

| File | Address | md5 |
|---|---|---|
| `planb-stock-uboot/boot.img` (v27) | `0xE000` | `8abbb3cbd737cf4eb2957d189d735dd5` |
| `planb-stock-uboot/parameter.txt` (native) | `0x0` | `ab7c574450b6494aa30dcce73e08852f09c55df4cb05bf83d47ad4a756927950` |

zImage md5 `185d999b4f517cf25e9abb766c713b67` (6.6.89-rk3128+).
resource.img v23.2 kept as is (not reflashed).

**Expected after flash**: cmdline has NO `video=`; dmesg shows
`Update mode to 1920x1080p60` exactly once at ~3.4s; NO p120 flips
after that (no mode >165 left to restore); picture from the moment fbcon comes up.
`summary`: `Display mode: 1920x1080p60`, dclk 148500, addr ≠ 0.

**Rollback**: reflash `parameter.txt.force` @0x0 (keep boot v27 —
force 1080p60 ≤165MHz so it still works with kernel v27; back to the
Z.28 configuration). Kernel #26 (v24.4c `f1e30989…`) has no external copy left
— rebuild if needed: restore `inno_hdmi.c.orig-v27` then rerun
planb-v27.sh (the tree already keeps dwmac v24.4c).

## Z.30 — v28: fbdev shadow buffer + damage blit (fixes tearing/torn image)

**Symptom**: after Z.29 the console shows but the picture looks "torn
and smeared" when there is motion; the more motion, the worse it gets.

**RCA** (NOTES §94): fbcon draws **directly into the VOP buffer being scanned out**
(no shadow, no damage tracking — the vendor fbdev uses
`__FB_DEFAULT_DMAMEM_OPS_DRAW` = sys ops straight into WC GEM) → classic
tearing + sys_copyarea on WRITE_COMBINE memory reads/writes slowly,
making artifacts persist across multiple frames. aclk 297MHz, dclk 148.5 — DDR
bandwidth is not the cause.

**Patch (kernel #28)**: `rockchip_drm_fbdev.c` moves to the
shadow-buffer model like upstream `drm_fbdev_generic`: fbcon draws into shadow
sysmem cached (fast), ops wrapped with `drm_fb_helper_damage_area`,
`fb_dirty` blits the clip region to GEM scanout. GEM remains the scanout
buffer — modetest/X later on unchanged. Backup: `rockchip_drm_fbdev.c.orig-v28`.
Build lesson: heredocs through pwsh double quotes get mangled — always
write patches as a .py file; string-match guards easily skip a block when a
previous block already added the string to detect (`out_release_info`).

**Flash 1 file** (parameter kept as native `ab7c5744…`):

| File | Address | md5 |
|---|---|---|
| `planb-stock-uboot/boot.img` (v28) | `0xE000` | `86687c83060950fe363414b7286300e6` |

zImage md5 `bec235981475e78a1501b61c5a5eb9d9` (6.6.89-rk3128+).

**Expected**: console draws smoothly, no tearing when scrolling/text runs;
every content update lags at most 1 frame (shadow → scanout). If
STILL torn under heavy motion → suspect DDR bandwidth → try 720p
(`parameter.txt.force720` @0x0, md5 see NOTES §94) to triage.

Rollback: boot v27 (`archive/boot-v27.img` `8abbb3cb…`) @0xE000.

---

## FINAL STATE (Sep 9, after NOTES §95-99)

**Arc tearing outcome:**
- Kernel #28 (fbdev shadow) DID fix console tearing — user confirmed
  smooth scrolling; flood test 17.688 copy iterations, p90 6.7µs, 0 frame overruns.
- Remaining tearing belongs to the **Xorg desktop** (no vsync, low llvmpipe fps).
- User decided to **drop the desktop**: `systemctl disable lightdm` has been run.
- Current TV: tty1 console @1280x720p60 (from cmdline `video=HDMI-A-1:
  1280x720@60e` in the native parameter being flashed).
- SSH is the main interaction path; the TV is used only at boot/debug.

**Nothing more to flash.** Boot v28 (md5 86687c83…) @0xE000 +
native parameter is the final configuration. `/etc/X11/xorg.conf.d/
60-tearfree-720p.conf` is still on the box (harmless, reuse if a desktop is needed).

Rollback desktop: `systemctl enable --now lightdm`.

---

## SINGLE-FILE UPDATE.IMG (Sep 9) — `update_armbian_v28-v232.img`

⚠️ **The FIRST build of `update_armbian_v28.img` is BROKEN — DO NOT FLASH** (root packed
the wrong `armbian_rootfs_26.2_xmio.img` — usrmerge broken: `/lib` is a real
directory containing only `modules`, missing `/lib/systemd/systemd` → `run-init: /sbin/
init: No such file or directory` → kernel panic. File kept as an error
specimen, delete when convenient).

Package the entire firmware into **1 flashable `.img` file via RKDevTool/
UpgradeTool exactly like stock Android** (`update_(VTIDC_XMIO_20160128_for_nandflash).img`),
following the Firefly wiki procedure exactly (Customize Firmware): `afptool -pack` →
`img_maker`. Tools: `work/rk2918_tools/` (mirror of dayongxie/rk2918_tools,
patched for buffer 4096 + chiptype "A213"), script `tools/build-update-img.sh`,
verify `tools/rkfw-verify.py`.

**File:** `output/planb-stock-uboot/update_armbian_v28-v232.img` —
1.174.931.928 B (1.12 GiB), md5 `f3223b97b5a867f8fc2fe4249708812c`
(trailer md5 written by the tool: `7fe4b32c15b8a915f2b714efbc2505ff`), SHA256
`284d09f2085293d073658b7e60f2d81cee3a14c4e570dc1c0d3b617936f962e9`.

**Inside** (RKFW → MiniLoader V2.25 → RKAF, 11 parts):

| Part | Contents | nand_addr | md5 |
|---|---|---|---|
| bootloader | MiniLoader V2.25 (stock) | — | `28ea90194bb0fd21d2c2e3a31a424de9` |
| parameter | force720 + root 1.5GB explicit | 0x0 | `8d0beb29b8e08726dcb5f7fb5f52b57d` |
| uboot | stock 263 | 0x2000 | `0c9788a3a729178a1b2eeb15656450b2` |
| misc | zero (normal boot) | 0x4000 | `addee4c566ad6623892c2c2d86f20877` |
| baseparamer | 720P | 0x6000 | `2d6b6a4e657ce4103c4eea73baec3b52` |
| resource | v23.2 (DTB b218d71d) | 0x6800 | `b12893c9a630ee32304c4c3386760580` |
| boot | kernel v28 (fbdev shadow) | 0xE000 | `86687c83060950fe363414b7286300e6` |
| root | **armbian rootfs v23.2** (production lineage) | 0x17000 | `657da568d2a31ae1676eda78a63091b9` |

Roundtrip verified on the v232 build: trailer md5 matches, loader = stock
bit-perfect, every component after unpack has an md5 matching its source (rootfs
`657da568…` = exactly the build running on the box), parameter unchanged, init
chain `/sbin/init → /lib/systemd/systemd` resolves OK directly on the
extracted file. Root written 1.5GB explicit (`0x00300000@0x00017000`) — actual
rootfs 1.08GB. Scripts in the package are no-ops (the native layout has no
recovery/backup, so the Android upgrade logic is not used).

**How to flash 1 file:** RKDevTool → the "Upgrade Firmware" tab → Load
`update_armbian_v28-v232.img` → Upgrade (box into MaskRom/loader mode
as before). NOTE: this package flashes OVER the native layout as a full image — same
the old stock-style full-image flash, not per-partition flashing. After flash:
SSH root@… pw 1234 as usual (v23.2 does NOT enable lightdm by default — the
settled console-only state).

**Do not use this package when** you only need to fix boot/parameter — flashing
1-2 files per the sections above is far faster.

**Build lesson (NOTES §101):** afptool reading files through the Windows mount
can fail fread SILENTLY when a file is locked (AV scan) → it packs a size-0
rootfs and still says "Pack OK!". Always copy the rootfs into the container fs
+ assert the md5 BEFORE packing (the script asserts `657da568…`).

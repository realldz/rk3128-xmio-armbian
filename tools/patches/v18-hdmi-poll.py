#!/usr/bin/env python3
# v18-hdmi-poll.py — add connector polling fallback to inno_hdmi.c.
#
# Current state: connector.polled = DRM_CONNECTOR_POLL_HPD only. If the
# HPD IRQ never fires (or HPD changed while the driver was mid-init),
# the kernel never re-detects: EDID is never read, and the connector
# stays "disconnected" forever (boot log: "Cannot find any crtc or
# sizes"). Adding CONNECT|DISCONNECT makes DRM's 10s delayed poll run
# inno_hdmi_connector_detect() regardless of IRQ delivery — if the HPD
# bit reads correctly, EDID gets fetched on the first poll.
#
# Idempotent via marker V18HPD.
import io

P = "/vol/kernel-src/drivers/gpu/drm/rockchip/inno_hdmi.c"
with io.open(P, "r", encoding="utf-8") as f:
    s = f.read()

if "V18HPD" in s:
    print("V18HPD_OK: already patched")
    raise SystemExit(0)

old = "\thdmi->connector.polled = DRM_CONNECTOR_POLL_HPD;\n"
n = s.count(old)
assert n == 1, "polled anchor x%d" % n
new = ("\t/* V18HPD: poll fallback so EDID/detect survives dead HPD IRQ */\n"
       "\thdmi->connector.polled = DRM_CONNECTOR_POLL_HPD |\n"
       "\t\tDRM_CONNECTOR_POLL_CONNECT | DRM_CONNECTOR_POLL_DISCONNECT;\n")
s = s.replace(old, new)

with io.open(P, "w", encoding="utf-8", newline="") as f:
    f.write(s)
print("V18HPD_OK: connector poll fallback added")

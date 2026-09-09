#!/usr/bin/env python3
# v28-fix-unused.py — bo 2 bien khong dung (WERROR safety)
p = '/vol/kernel-src/drivers/gpu/drm/rockchip/rockchip_drm_fbdev.c'
src = open(p).read()

a = """\tstruct rockchip_gem_object *rk_obj;
\tstruct drm_device *dev = helper->dev;
\tsize_t offset, len;"""
b = """\tstruct rockchip_gem_object *rk_obj;
\tsize_t offset, len;"""
assert a in src
src = src.replace(a, b, 1)

c = """static void rockchip_fbdev_fb_destroy(struct fb_info *info)
{
\tstruct drm_fb_helper *fb_helper = info->par;
\tvoid *shadow = info->screen_buffer;"""
d = """static void rockchip_fbdev_fb_destroy(struct fb_info *info)
{
\tvoid *shadow = info->screen_buffer;"""
assert c in src
src = src.replace(c, d, 1)

open(p, 'w').write(src)
print('unused vars removed')

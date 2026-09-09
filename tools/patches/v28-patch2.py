#!/usr/bin/env python3
# v28-patch2.py — sua 3 loi: shadow_buffer (khong co field), forward decl defio_write, labels tail bi skip
p = '/vol/kernel-src/drivers/gpu/drm/rockchip/rockchip_drm_fbdev.c'
src = open(p).read()

# 1) forward declaration cho defio_write (ops dung truoc khi dinh nghia)
old = """static void rockchip_fbdev_fillrect(struct fb_info *info,"""
new = """static ssize_t rockchip_fbdev_defio_write(struct fb_info *info,
\t\t\t\t\t  const char __user *buf,
\t\t\t\t\t  size_t count, loff_t *ppos);

static void rockchip_fbdev_fillrect(struct fb_info *info,"""
assert old in src and 'rockchip_fbdev_defio_write(struct fb_info *info,\n\t\t\t\t\t  const char __user *buf,\n\t\t\t\t\t  size_t count, loff_t *ppos);' not in src
src = src.replace(old, new, 1)

# 2) khai bao bien local shadow trong create()
old = """\tstruct fb_info *fbi;
\tsize_t size;
\tint ret;"""
new = """\tstruct fb_info *fbi;
\tsize_t size;
\tvoid *shadow;
\tint ret;"""
assert old in src
src = src.replace(old, new, 1)

# 3) probe: helper->shadow_buffer -> shadow local
old = """\tsize = mode_cmd.pitches[0] * mode_cmd.height;
\thelper->shadow_buffer = vzalloc(size);
\tif (!helper->shadow_buffer) {
\t\tret = -ENOMEM;
\t\tgoto out;
\t}"""
new = """\tsize = mode_cmd.pitches[0] * mode_cmd.height;
\tshadow = vzalloc(size);
\tif (!shadow) {
\t\tret = -ENOMEM;
\t\tgoto out;
\t}"""
assert old in src
src = src.replace(old, new, 1)

# 4) screen: helper->shadow_buffer + offset -> shadow + offset
old = """\tfbi->screen_buffer = helper->shadow_buffer + offset;"""
new = """\tfbi->screen_buffer = shadow + offset;"""
assert old in src
src = src.replace(old, new, 1)

# 5) tail labels: ap dung that su (guard cu bi skip vi 'out_release_info' da co trong goto)
old = """\treturn 0;

out:
\tdrm_gem_object_put(&rk_obj->base);
\treturn ret;
}"""
new = """\treturn 0;

out_release_info:
\tdrm_fb_helper_release_info(helper);
out_vfree:
\tvfree(shadow);
out:
\tdrm_gem_object_put(&rk_obj->base);
\treturn ret;
}"""
assert old in src and 'out_release_info:' not in src
src = src.replace(old, new, 1)

open(p, 'w').write(src)
print('V28 patch2 OK')

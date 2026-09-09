#!/usr/bin/env python3
# v28-patch.py — shadow-buffer + damage blit cho rockchip_drm_fbdev.c
import sys

p = '/vol/kernel-src/drivers/gpu/drm/rockchip/rockchip_drm_fbdev.c'
src = open(p).read()

# 0) xac nhan backup ton tai
import os
assert os.path.exists(p + '.orig-v28'), 'backup missing!'

# 1) include vmalloc
old_inc = '#include "rockchip_drm_fbdev.h"'
new_inc = '#include "rockchip_drm_fbdev.h"\n#include <linux/vmalloc.h>'
if new_inc not in src:
    assert old_inc in src
    src = src.replace(old_inc, new_inc, 1)

# 2) ops moi: wrappers + dirty + destroy
old_ops = """static const struct fb_ops rockchip_drm_fbdev_ops = {
\t.owner\t\t= THIS_MODULE,
\tDRM_FB_HELPER_DEFAULT_OPS,
\t.fb_mmap\t= rockchip_fbdev_mmap,
\t__FB_DEFAULT_DMAMEM_OPS_DRAW,

};"""
new_ops = """/*
 * V28FIX: fbcon drew directly into the scanout buffer while the VOP
 * was scanning it out -> tearing on every update. Route all fbdev
 * drawing into a shadow buffer in cached system memory, collect the
 * damage, and blit the damaged region into the scanout GEM object
 * from the fb_dirty callback (which runs under the helper's worker).
 */
static void rockchip_fbdev_fillrect(struct fb_info *info,
\t\t\t\t    const struct fb_fillrect *rect)
{
\tsys_fillrect(info, rect);
\tdrm_fb_helper_damage_area(info, rect->dx, rect->dy,
\t\t\t\t  rect->width, rect->height);
}

static void rockchip_fbdev_copyarea(struct fb_info *info,
\t\t\t\t    const struct fb_copyarea *area)
{
\tsys_copyarea(info, area);
\tdrm_fb_helper_damage_area(info, area->dx, area->dy,
\t\t\t\t  area->width, area->height);
}

static void rockchip_fbdev_imageblit(struct fb_info *info,
\t\t\t\t     const struct fb_image *image)
{
\tsys_imageblit(info, image);
\tdrm_fb_helper_damage_area(info, image->dx, image->dy,
\t\t\t\t  image->width, image->height);
}

static int rockchip_fbdev_dirty(struct drm_fb_helper *helper,
\t\t\t\tstruct drm_clip_rect *clip)
{
\tstruct drm_framebuffer *fb = helper->fb;
\tstruct rockchip_gem_object *rk_obj;
\tstruct drm_device *dev = helper->dev;
\tsize_t offset, len;
\tunsigned int y;
\tvoid *src, *dst;
\tint ret = 0;

\tif (!(clip->x1 < clip->x2 && clip->y1 < clip->y2))
\t\treturn 0;

\trk_obj = to_rockchip_obj(fb->obj[0]);
\tif (WARN_ON(!rk_obj->kvaddr))
\t\treturn -EINVAL;

\toffset = clip->y1 * fb->pitches[0] + clip->x1 * fb->format->cpp[0];
\tlen = (clip->x2 - clip->x1) * fb->format->cpp[0];
\tsrc = helper->info->screen_buffer + offset;
\tdst = rk_obj->kvaddr + offset;

\tmutex_lock(&helper->lock);
\tfor (y = clip->y1; y < clip->y2; y++) {
\t\tmemcpy(dst, src, len);
\t\tsrc += fb->pitches[0];
\t\tdst += fb->pitches[0];
\t}
\tmutex_unlock(&helper->lock);

\tif (fb->funcs->dirty)
\t\tret = fb->funcs->dirty(fb, NULL, 0, 0, clip, 1);

\treturn ret;
}

static void rockchip_fbdev_fb_destroy(struct fb_info *info)
{
\tstruct drm_fb_helper *fb_helper = info->par;
\tvoid *shadow = info->screen_buffer;

\tfb_deferred_io_cleanup(info);
\tvfree(shadow);
\tframebuffer_release(info);
}

static int rockchip_fbdev_fb_release(struct fb_info *info, int user)
{
\treturn 0;
}

static const struct fb_ops rockchip_drm_fbdev_ops = {
\t.owner\t\t= THIS_MODULE,
\tDRM_FB_HELPER_DEFAULT_OPS,
\t.fb_mmap\t= rockchip_fbdev_mmap,
\t.fb_read\t= fb_sys_read,
\t.fb_write\t= rockchip_fbdev_defio_write,
\t.fb_fillrect\t= rockchip_fbdev_fillrect,
\t.fb_copyarea\t= rockchip_fbdev_copyarea,
\t.fb_imageblit\t= rockchip_fbdev_imageblit,
\t.fb_release\t= rockchip_fbdev_fb_release,
\t.fb_destroy\t= rockchip_fbdev_fb_destroy,
};"""
if 'V28FIX' not in src:
    assert old_ops in src, 'ops block not found'
    src = src.replace(old_ops, new_ops, 1)

# 3) probe: shadow alloc
old_probe = """\tfbi = drm_fb_helper_alloc_info(helper);
\tif (IS_ERR(fbi)) {
\t\tDRM_DEV_ERROR(dev->dev, \"Failed to create framebuffer info.\\n\");
\t\tret = PTR_ERR(fbi);
\t\tgoto out;
\t}"""
new_probe = """\tsize = mode_cmd.pitches[0] * mode_cmd.height;
\thelper->shadow_buffer = vzalloc(size);
\tif (!helper->shadow_buffer) {
\t\tret = -ENOMEM;
\t\tgoto out;
\t}

\tfbi = drm_fb_helper_alloc_info(helper);
\tif (IS_ERR(fbi)) {
\t\tDRM_DEV_ERROR(dev->dev, \"Failed to create framebuffer info.\\n\");
\t\tret = PTR_ERR(fbi);
\t\tgoto out_vfree;
\t}"""
if 'shadow_buffer = vzalloc' not in src:
    assert old_probe in src, 'probe block not found'
    src = src.replace(old_probe, new_probe, 1)

# 4) screen_base -> shadow
old_screen = """\tfbi->screen_base = rk_obj->kvaddr + offset;
\tfbi->screen_size = rk_obj->base.size;
\tfbi->fix.smem_len = rk_obj->base.size;"""
new_screen = """\tfbi->flags |= FBINFO_VIRTFB | FBINFO_READS_FAST;
\tfbi->screen_buffer = helper->shadow_buffer + offset;
\tfbi->screen_size = size;
\tfbi->fix.smem_len = size;

\thelper->fbdefio.delay = HZ / 20;
\thelper->fbdefio.deferred_io = drm_fb_helper_deferred_io;
\tfbi->fbdefio = &helper->fbdefio;
\tret = fb_deferred_io_init(fbi);
\tif (ret)
\t\tgoto out_release_info;"""
if 'fbdefio.delay' not in src:
    assert old_screen in src, 'screen block not found'
    src = src.replace(old_screen, new_screen, 1)

# 5) error path
old_tail = """\tDRM_DEBUG_KMS(\"FB [%dx%d]-%d kvaddr=%p offset=%ld size=%zu\\n\",
\t\t      fb->width, fb->height, fb->format->depth,
\t\t      rk_obj->kvaddr,
\t\t      offset, size);

\treturn 0;

out:
\tdrm_gem_object_put(&rk_obj->base);
\treturn ret;
}"""
new_tail = """\tDRM_DEBUG_KMS(\"FB [%dx%d]-%d kvaddr=%p offset=%ld size=%zu\\n\",
\t\t      fb->width, fb->height, fb->format->depth,
\t\t      rk_obj->kvaddr,
\t\t      offset, size);

\treturn 0;

out_release_info:
\tdrm_fb_helper_release_info(helper);
out_vfree:
\tvfree(helper->shadow_buffer);
\thelper->shadow_buffer = NULL;
out:
\tdrm_gem_object_put(&rk_obj->base);
\treturn ret;
}"""
if 'out_release_info' not in src:
    assert old_tail in src, 'tail block not found'
    src = src.replace(old_tail, new_tail, 1)

# 6) defio write helper + funcs
old_funcs = """static const struct drm_fb_helper_funcs rockchip_drm_fb_helper_funcs = {
\t.fb_probe = rockchip_drm_fbdev_create,
};"""
new_funcs = """static ssize_t rockchip_fbdev_defio_write(struct fb_info *info,
\t\t\t\t\t  const char __user *buf,
\t\t\t\t\t  size_t count, loff_t *ppos)
{
\tunsigned long offset = *ppos;
\tssize_t ret;

\tret = fb_sys_write(info, buf, count, ppos);
\tif (ret > 0)
\t\tdrm_fb_helper_damage_range(info, offset, ret);
\treturn ret;
}

static const struct drm_fb_helper_funcs rockchip_drm_fb_helper_funcs = {
\t.fb_probe = rockchip_drm_fbdev_create,
\t.fb_dirty = rockchip_fbdev_dirty,
};"""
if 'fb_dirty = rockchip_fbdev_dirty' not in src:
    assert old_funcs in src, 'funcs block not found'
    src = src.replace(old_funcs, new_funcs, 1)

open(p, 'w').write(src)
print('V28 patch applied OK')

/*
 * Copyright (c) 2016, Fuzhou Rockchip Electronics Co., Ltd
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

#define pr_fmt(fmt) "rk_nand: " fmt

#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/module.h>
#include <linux/list.h>
#include <linux/fs.h>
#include <linux/blkdev.h>
#include <linux/blk-mq.h>
#include <linux/blkpg.h>
#include <linux/spinlock.h>
#include <linux/hdreg.h>
#include <linux/init.h>
#include <linux/semaphore.h>
#include <linux/platform_device.h>
#include <linux/interrupt.h>
#include <linux/timer.h>
#include <linux/delay.h>
#include <linux/clk.h>
#include <linux/mutex.h>
#include <linux/wait.h>
#include <linux/sched.h>
#include <linux/freezer.h>
#include <linux/kthread.h>
#include <linux/err.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/version.h>
#include <linux/soc/rockchip/rk_vendor_storage.h>

#include "rk_nand_blk.h"
#include "rk_ftl_api.h"
#include "rk_nand_base.h"

static struct nand_part disk_array[MAX_PART_COUNT];
static int g_max_part_num;

#define PART_READONLY 0x85
#define PART_WRITEONLY 0x86
#define PART_NO_ACCESS 0x87

static unsigned long total_read_data;
static unsigned long total_write_data;
static unsigned long total_read_count;
static unsigned long total_write_count;
static unsigned long total_discard_count;
static unsigned long total_flush_count;
static unsigned long ftl_read_error_count;
static unsigned long ftl_write_error_count;
static unsigned long ftl_discard_error_count;
static unsigned long ftl_flush_error_count;
static unsigned long ioerr_no_dev_count;
static unsigned long ioerr_bounds_count;
static unsigned long ioerr_access_count;
static unsigned long ioerr_unsupported_count;
static unsigned long zero_len_read_count;
static unsigned long zero_len_write_count;
static unsigned long zero_len_discard_count;
static int rk_nand_dev_initialised;
static unsigned long rk_ftl_gc_do;
static DECLARE_WAIT_QUEUE_HEAD(rknand_thread_wait);
static unsigned long rk_ftl_gc_jiffies;

static char *mtd_read_temp_buffer;
#define MTD_RW_SECTORS (512)
#define RKNAND_PROC_FTL_DUMP_SIZE (64 * 1024)

#define DISABLE_WRITE _IO('V', 0)
#define ENABLE_WRITE _IO('V', 1)
#define DISABLE_READ _IO('V', 2)
#define ENABLE_READ _IO('V', 3)
static int rknand_proc_show(struct seq_file *m, void *v)
{
	char *ftl_dump;
	int ftl_len;
	int ret;

	ftl_dump = kvzalloc(RKNAND_PROC_FTL_DUMP_SIZE, GFP_KERNEL);
	if (!ftl_dump)
		return -ENOMEM;

	rknand_device_lock();
	ftl_len = rknand_proc_ftlread(ftl_dump);
	rknand_device_unlock();
	if (ftl_len < 0) {
		kvfree(ftl_dump);
		return ftl_len;
	}

	if (ftl_len > RKNAND_PROC_FTL_DUMP_SIZE)
		ftl_len = RKNAND_PROC_FTL_DUMP_SIZE;

	ret = seq_write(m, ftl_dump, ftl_len);
	kvfree(ftl_dump);
	if (ret)
		return ret;

	seq_printf(m, "Total Read %ld KB\n", total_read_data >> 1);
	seq_printf(m, "Total Write %ld KB\n", total_write_data >> 1);
	seq_printf(m, "total_write_count %ld\n", total_write_count);
	seq_printf(m, "total_read_count %ld\n", total_read_count);
	seq_printf(m, "total_discard_count %ld\n", total_discard_count);
	seq_printf(m, "total_flush_count %ld\n", total_flush_count);
	seq_printf(m, "ftl_read_error_count %ld\n", ftl_read_error_count);
	seq_printf(m, "ftl_write_error_count %ld\n", ftl_write_error_count);
	seq_printf(m, "ftl_discard_error_count %ld\n", ftl_discard_error_count);
	seq_printf(m, "ftl_flush_error_count %ld\n", ftl_flush_error_count);
	seq_printf(m, "ioerr_no_dev_count %ld\n", ioerr_no_dev_count);
	seq_printf(m, "ioerr_bounds_count %ld\n", ioerr_bounds_count);
	seq_printf(m, "ioerr_access_count %ld\n", ioerr_access_count);
	seq_printf(m, "ioerr_unsupported_count %ld\n", ioerr_unsupported_count);
	seq_printf(m, "zero_len_read_count %ld\n", zero_len_read_count);
	seq_printf(m, "zero_len_write_count %ld\n", zero_len_write_count);
	seq_printf(m, "zero_len_discard_count %ld\n", zero_len_discard_count);
	return 0;
}

static int rknand_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, rknand_proc_show, pde_data(inode));
}

static const struct proc_ops rknand_proc_fops = {
	.proc_open	= rknand_proc_open,
	.proc_read	= seq_read,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int rknand_create_procfs(void)
{
	struct proc_dir_entry *ent;

	ent = proc_create_data("rknand", 0444, NULL, &rknand_proc_fops,
			       (void *)0);
	if (!ent)
		return -1;

	return 0;
}

static struct mutex g_rk_nand_ops_mutex;

static void rknand_device_lock_init(void)
{
	mutex_init(&g_rk_nand_ops_mutex);
}

void rknand_device_lock(void)
{
	mutex_lock(&g_rk_nand_ops_mutex);
}

int rknand_device_trylock(void)
{
	return mutex_trylock(&g_rk_nand_ops_mutex);
}

void rknand_device_unlock(void)
{
	mutex_unlock(&g_rk_nand_ops_mutex);
}

static int rknand_ftl_flush_locked(void)
{
	total_flush_count++;
	rk_ftl_cache_write_back();
	return 0;
}

static void rknand_log_ioerr(struct request *req, struct nand_blk_dev *dev,
			     const char *reason, unsigned long ftl_start,
			     unsigned long sectors, int ret)
{
	struct gendisk *disk = NULL;

	if (req->part)
		disk = req->part->bd_disk;
	else if (req->q)
		disk = req->q->disk;

	pr_warn_ratelimited("ioerr: %s disk=%s op=%s flags=0x%llx pos=%llu cur_sectors=%u data_sectors=%u phys_seg=%u ftl_start=0x%lx sectors=0x%lx off=0x%lx cap=%llu ret=%d\n",
			    reason,
			    disk ? disk->disk_name : "<none>",
			    blk_op_str(req_op(req)),
			    (unsigned long long)req->cmd_flags,
			    (unsigned long long)blk_rq_pos(req),
			    blk_rq_cur_sectors(req),
			    req->__data_len >> SECTOR_SHIFT,
			    blk_rq_nr_phys_segments(req),
			    ftl_start, sectors,
			    dev ? dev->off_size : 0,
			    disk ? (unsigned long long)get_capacity(disk) : 0,
			    ret);
}

static int nand_dev_transfer(struct nand_blk_dev *dev,
			     unsigned long start,
			     unsigned long nsector,
			     char *buf,
			     int cmd)
{
	int ret;

	if (dev->disable_access ||
	    ((cmd == WRITE) && dev->readonly) ||
	    ((cmd == READ) && dev->writeonly)) {
		return BLK_STS_IOERR;
	}

	start += dev->off_size;

	switch (cmd) {
	case REQ_OP_READ:
		total_read_data += nsector;
		total_read_count++;
		ret = FtlRead(0, start, nsector, buf);
		if (ret) {
			ftl_read_error_count++;
			ret = BLK_STS_IOERR;
		}
		break;

	case REQ_OP_WRITE:
		total_write_data += nsector;
		total_write_count++;
		ret = FtlWrite(0, start, nsector, buf);
		if (ret) {
			ftl_write_error_count++;
			ret = BLK_STS_IOERR;
		}
		break;

	default:
		ret = BLK_STS_IOERR;
		break;
	}

	return ret;
}

static int req_check_buffer_align(struct request *req, char **pbuf)
{
	int nr_vec = 0;
	struct bio_vec bv;
	struct req_iterator iter;
	char *buffer;
	void *firstbuf = 0;
	char *nextbuffer = 0;

	rq_for_each_segment(bv, req, iter) {
		/* high mem return 0 and using kernel buffer */
		if (PageHighMem(bv.bv_page))
			return 0;

		buffer = page_address(bv.bv_page) + bv.bv_offset;
		if (!buffer)
			return 0;
		if (!firstbuf)
			firstbuf = buffer;
		nr_vec++;
		if (nextbuffer && nextbuffer != buffer)
			return 0;
		nextbuffer = buffer + bv.bv_len;
	}
	*pbuf = firstbuf;
	return 1;
}

static struct gendisk *rknand_req_to_disk(struct request *req)
{
	if (req->part && req->part->bd_disk)
		return req->part->bd_disk;

	if (req->q)
		return req->q->disk;

	return NULL;
}

static struct nand_blk_dev *rknand_req_to_dev(struct request *req)
{
	struct gendisk *disk = rknand_req_to_disk(req);

	return disk ? disk->private_data : NULL;
}

static blk_status_t do_blktrans_all_request(struct request *req)
{
	struct nand_blk_dev *dev = rknand_req_to_dev(req);
	struct gendisk *disk;
	sector_t capacity;
	unsigned long block, nsect, ftl_start;
	char *buf = NULL, *page_buf;
	struct req_iterator rq_iter;
	struct bio_vec bvec;
	int ret = BLK_STS_IOERR;
	unsigned long total_nsect;

	if (!dev) {
		ioerr_no_dev_count++;
		rknand_log_ioerr(req, NULL, "missing device", 0, 0, -ENODEV);
		return BLK_STS_IOERR;
	}

	disk = rknand_req_to_disk(req);
	if (!disk) {
		ioerr_no_dev_count++;
		rknand_log_ioerr(req, NULL, "missing disk", 0, 0, -ENODEV);
		return BLK_STS_IOERR;
	}

	if (req_op(req) == REQ_OP_FLUSH) {
		rknand_ftl_flush_locked();
		return BLK_STS_OK;
	}

	if (req->cmd_flags & REQ_PREFLUSH)
		rknand_ftl_flush_locked();

	block = blk_rq_pos(req);
	nsect = blk_rq_cur_bytes(req) >> 9;
	total_nsect = (req->__data_len) >> 9;
	ftl_start = block + dev->off_size;
	capacity = get_capacity(disk);

	if (total_nsect > capacity || block > capacity - total_nsect) {
		ioerr_bounds_count++;
		rknand_log_ioerr(req, dev, "request beyond disk capacity",
				 ftl_start, total_nsect, -ERANGE);
		return BLK_STS_IOERR;
	}

	if (dev->disable_access ||
	    ((req_op(req) == REQ_OP_WRITE) && dev->readonly) ||
	    ((req_op(req) == REQ_OP_READ) && dev->writeonly)) {
		ioerr_access_count++;
		rknand_log_ioerr(req, dev, "access disabled",
				 ftl_start, total_nsect, -EACCES);
		return BLK_STS_IOERR;
	}

	switch (req_op(req)) {
	case REQ_OP_DISCARD:
		ioerr_unsupported_count++;
		rknand_log_ioerr(req, dev, "discard not advertised",
				 ftl_start, nsect, -EOPNOTSUPP);
		return BLK_STS_NOTSUPP;
	case REQ_OP_READ:
		if (!total_nsect) {
			zero_len_read_count++;
			return BLK_STS_OK;
		}
		buf = mtd_read_temp_buffer;
		req_check_buffer_align(req, &buf);
		ret = nand_dev_transfer(dev, block, total_nsect, buf, REQ_OP_READ);
		if (buf == mtd_read_temp_buffer) {
			char *p = buf;

			rq_for_each_segment(bvec, req, rq_iter) {
				page_buf = kmap_atomic(bvec.bv_page);

				memcpy(page_buf + bvec.bv_offset, p, bvec.bv_len);
				p += bvec.bv_len;
				kunmap_atomic(page_buf);
			}
		}

		if (ret) {
			rknand_log_ioerr(req, dev, "FtlRead failed",
					 ftl_start, total_nsect, ret);
			return BLK_STS_IOERR;
		}
		else
			return BLK_STS_OK;
	case REQ_OP_WRITE:
		if (!total_nsect) {
			zero_len_write_count++;
			if (req->cmd_flags & REQ_FUA)
				rknand_ftl_flush_locked();
			return BLK_STS_OK;
		}
		buf = mtd_read_temp_buffer;
		req_check_buffer_align(req, &buf);

		if (buf == mtd_read_temp_buffer) {
			char *p = buf;

			rq_for_each_segment(bvec, req, rq_iter) {
				page_buf = kmap_atomic(bvec.bv_page);
				memcpy(p, page_buf + bvec.bv_offset, bvec.bv_len);
				p += bvec.bv_len;
				kunmap_atomic(page_buf);
			}
		}

		ret = nand_dev_transfer(dev, block, total_nsect, buf, REQ_OP_WRITE);

		if (ret) {
			rknand_log_ioerr(req, dev, "FtlWrite failed",
					 ftl_start, total_nsect, ret);
			return BLK_STS_IOERR;
		}

		if (req->cmd_flags & REQ_FUA)
			rknand_ftl_flush_locked();

		return BLK_STS_OK;

	default:
		ioerr_unsupported_count++;
		rknand_log_ioerr(req, dev, "unsupported request op",
				 ftl_start, total_nsect, -EOPNOTSUPP);
		return BLK_STS_IOERR;
	}
}

static struct request *rk_nand_next_request(struct nand_blk_ops *nand_ops)
{
	struct request *rq;

	rq = list_first_entry_or_null(&nand_ops->rq_list, struct request, queuelist);
	if (rq) {
		list_del_init(&rq->queuelist);
		blk_mq_start_request(rq);
		return rq;
	}

	return NULL;
}

static void rk_nand_blktrans_work(struct nand_blk_ops *nand_ops)
	__releases(&nand_ops->queue_lock)
	__acquires(&nand_ops->queue_lock)
{
	struct request *req = NULL;

	while (1) {
		blk_status_t res;

		req = rk_nand_next_request(nand_ops);
		if (!req)
			break;

		spin_unlock_irq(&nand_ops->queue_lock);

		rknand_device_lock();
		res = do_blktrans_all_request(req);
		rknand_device_unlock();

		if (!blk_update_request(req, res, req->__data_len)) {
			__blk_mq_end_request(req, res);
			req = NULL;
		}

		spin_lock_irq(&nand_ops->queue_lock);
	}
}

static blk_status_t rk_nand_queue_rq(struct blk_mq_hw_ctx *hctx,
				     const struct blk_mq_queue_data *bd)
{
	struct nand_blk_ops *nand_ops;

	nand_ops = hctx->queue->queuedata;
	if (!nand_ops) {
		blk_mq_start_request(bd->rq);
		return BLK_STS_IOERR;
	}

	rk_ftl_gc_do = 0;
	spin_lock_irq(&nand_ops->queue_lock);
	list_add_tail(&bd->rq->queuelist, &nand_ops->rq_list);
	rk_nand_blktrans_work(nand_ops);
	spin_unlock_irq(&nand_ops->queue_lock);

	/* wake up gc thread */
	rk_ftl_gc_do = 1;
	wake_up(&nand_ops->thread_wq);

	return BLK_STS_OK;
}

static const struct blk_mq_ops rk_nand_mq_ops = {
	.queue_rq	= rk_nand_queue_rq,
};

static int nand_gc_thread(void *arg)
{
	struct nand_blk_ops *nand_ops = arg;
	int ftl_gc_status = 0;
	int req_empty_times = 0;
	int gc_done_times = 0;

	rk_ftl_gc_jiffies = HZ / 10;
	rk_ftl_gc_do = 1;

	while (!nand_ops->quit) {
		DECLARE_WAITQUEUE(wait, current);

		add_wait_queue(&nand_ops->thread_wq, &wait);
		set_current_state(TASK_INTERRUPTIBLE);

		if (rk_ftl_gc_do) {
			 /* do garbage collect at idle state */
			if (rknand_device_trylock()) {
				ftl_gc_status = rk_ftl_garbage_collect(1, 0);
				rknand_device_unlock();
				rk_ftl_gc_jiffies = HZ / 50;
				if (ftl_gc_status == 0) {
					gc_done_times++;
					if (gc_done_times > 10)
						rk_ftl_gc_jiffies = 10 * HZ;
					else
						rk_ftl_gc_jiffies = 1 * HZ;
				} else {
					gc_done_times = 0;
				}
			} else {
				rk_ftl_gc_jiffies = 1 * HZ;
			}
			req_empty_times++;
			if (req_empty_times < 10)
				rk_ftl_gc_jiffies = HZ / 50;
			/* cache write back after 100ms */
			if (req_empty_times >= 5 && req_empty_times < 7) {
				rknand_device_lock();
				rk_ftl_cache_write_back();
				rknand_device_unlock();
			}
		} else {
			req_empty_times = 0;
			rk_ftl_gc_jiffies = 1 * HZ;
		}
		wait_event_timeout(nand_ops->thread_wq, nand_ops->quit,
				   rk_ftl_gc_jiffies);
		remove_wait_queue(&nand_ops->thread_wq, &wait);
		continue;
	}
	pr_info("nand gc quited\n");
	nand_ops->nand_th_quited = 1;
	kthread_complete_and_exit(&nand_ops->thread_exit, 0);
	return 0;
}

static int rknand_open(struct gendisk *disk, blk_mode_t mode)
{
	return 0;
}

static void rknand_release(struct gendisk *disk)
{
};

static int rknand_ioctl(struct block_device *bdev, fmode_t mode,
			unsigned int cmd,
			unsigned long arg)
{
	struct nand_blk_dev *dev = bdev->bd_disk->private_data;

	switch (cmd) {
	case ENABLE_WRITE:
		dev->disable_access = 0;
		dev->readonly = 0;
		set_disk_ro(dev->blkcore_priv, 0);
		return 0;

	case DISABLE_WRITE:
		dev->readonly = 1;
		set_disk_ro(dev->blkcore_priv, 1);
		return 0;

	case ENABLE_READ:
		dev->disable_access = 0;
		dev->writeonly = 0;
		return 0;

	case DISABLE_READ:
		dev->writeonly = 1;
		return 0;
	default:
		return -ENOTTY;
	}
}

const struct block_device_operations nand_blktrans_ops = {
	.owner = THIS_MODULE,
	.open = rknand_open,
	.release = rknand_release,
	.ioctl = rknand_ioctl,
};

static struct nand_blk_ops mytr = {
	.name =  "rknand",
	.major = 31,
	.minorbits = 0,
	.owner = THIS_MODULE,
};

static int rknand_get_part(char *parts, struct nand_part *this_part,
			   int *part_index)
{
	char delim;
	unsigned int mask_flags;
	unsigned long long size, offset = ULLONG_MAX;
	char name[40] = "\0";

	if (*parts == '-') {
		size = ULLONG_MAX;
		parts++;
	} else {
		size = memparse(parts, &parts);
	}

	if (*parts == '@') {
		parts++;
		offset = memparse(parts, &parts);
	}

	mask_flags = 0;
	delim = 0;

	if (*parts == '(')
		delim = ')';

	if (delim) {
		char *p = strchr(parts + 1, delim);
		size_t len;

		if (!p)
			return 0;
		len = min_t(size_t, sizeof(name) - 1, p - (parts + 1));
		memcpy(name, parts + 1, len);
		name[len] = '\0';
		parts = p + 1;
	}

	if (strncmp(parts, "ro", 2) == 0) {
		mask_flags = PART_READONLY;
		parts += 2;
	}

	if (strncmp(parts, "wo", 2) == 0) {
		mask_flags = PART_WRITEONLY;
		parts += 2;
	}

	this_part->size = (unsigned long)size;
	this_part->offset = (unsigned long)offset;
	this_part->type = mask_flags;
	strscpy(this_part->name, name, sizeof(this_part->name));

	if ((++(*part_index) < MAX_PART_COUNT) && (*parts == ','))
		rknand_get_part(++parts, this_part + 1, part_index);

	return 1;
}

static int nand_parse_cmdline_part(struct nand_part *pdisk_part)
{
	char *cmdline;
	char *parts;
	unsigned int cap_size = rk_ftl_get_capacity();
	int part_num = 0;
	int i;

	cmdline = strstr(saved_command_line, "mtdparts=");
	if (!cmdline)
		return 0;

	cmdline += strlen("mtdparts=");
	if (strncmp(cmdline, "rk29xxnand:", strlen("rk29xxnand:")) != 0)
		return 0;

	parts = cmdline + strlen("rk29xxnand:");
	rknand_get_part(parts, pdisk_part, &part_num);
	if (part_num)
		pdisk_part[part_num - 1].size = cap_size -
			pdisk_part[part_num - 1].offset;

	for (i = 0; i < part_num; i++) {
		if (pdisk_part[i].size + pdisk_part[i].offset > cap_size) {
			pdisk_part[i].size = cap_size - pdisk_part[i].offset;
			pr_err("partition error....max cap:%x\n", cap_size);
			return pdisk_part[i].size ? i + 1 : i;
		}
	}

	return part_num;
}

static void rknand_init_queue(struct request_queue *rq)
{
	blk_queue_max_hw_sectors(rq, MTD_RW_SECTORS);
	blk_queue_max_segments(rq, MTD_RW_SECTORS);
	/*
	 * Keep discard hidden from filesystems while validating the old FTL
	 * discard path.  Unexpected discard requests are rejected instead of
	 * being passed to the FTL.
	 */
	blk_queue_max_discard_sectors(rq, 0);
	rq->limits.discard_granularity = 0;
	blk_queue_write_cache(rq, true, false);
}

static int nand_add_dev(struct nand_blk_ops *nand_ops, struct nand_part *part)
{
	struct nand_blk_dev *dev;
	struct gendisk *gd;
	int ret;

	if (part->size == 0)
		return -1;

	dev = kzalloc(sizeof(*dev), GFP_KERNEL);
	if (!dev)
		return -ENOMEM;

	gd = blk_mq_alloc_disk(nand_ops->tag_set, nand_ops);
	if (IS_ERR(gd)) {
		kfree(dev);
		return PTR_ERR(gd);
	}

	rknand_init_queue(gd->queue);
	dev->nand_ops = nand_ops;
	dev->size = part->size;
	dev->off_size = part->offset;
	dev->devnum = nand_ops->last_dev_index;
	list_add_tail(&dev->list, &nand_ops->devs);
	nand_ops->last_dev_index++;

	gd->major = nand_ops->major;
	gd->first_minor = (dev->devnum) << nand_ops->minorbits;
	gd->minors = 1;

	gd->fops = &nand_blktrans_ops;

	if (part->name[0]) {
		gd->flags |= GENHD_FL_NO_PART;
		snprintf(gd->disk_name, sizeof(gd->disk_name), "%s_%s",
			 nand_ops->name, part->name);
	} else {
		gd->flags |= GENHD_FL_NO_PART;
		snprintf(gd->disk_name, sizeof(gd->disk_name), "%s%d",
			 nand_ops->name, dev->devnum);
	}

	set_capacity(gd, dev->size);

	gd->private_data = dev;
	dev->blkcore_priv = gd;

	if (part->type == PART_NO_ACCESS)
		dev->disable_access = 1;

	if (part->type == PART_READONLY)
		dev->readonly = 1;

	if (part->type == PART_WRITEONLY)
		dev->writeonly = 1;

	if (dev->readonly)
		set_disk_ro(gd, 1);

	ret = device_add_disk(g_nand_device, gd, NULL);
	if (ret) {
		list_del(&dev->list);
		put_disk(gd);
		kfree(dev);
		return ret;
	}

	return 0;
}

static int nand_remove_dev(struct nand_blk_dev *dev)
{
	struct gendisk *gd;

	gd = dev->blkcore_priv;
	list_del(&dev->list);
	del_gendisk(gd);
	put_disk(gd);
	kfree(dev);

	return 0;
}

static int nand_blk_register(struct nand_blk_ops *nand_ops)
{
	struct task_struct *gc_task;
	struct nand_part part;
	int i;
	int ret;

	rk_nand_schedule_enable_config(1);
	nand_ops->quit = 0;
	nand_ops->nand_th_quited = 0;

	ret = register_blkdev(nand_ops->major, nand_ops->name);
	if (ret)
		return ret;

	mtd_read_temp_buffer = kmalloc(MTD_RW_SECTORS * 512, GFP_KERNEL | GFP_DMA);
	if (!mtd_read_temp_buffer) {
		ret = -ENOMEM;
		goto mtd_buffer_error;
	}

	init_completion(&nand_ops->thread_exit);
	init_waitqueue_head(&nand_ops->thread_wq);
	rknand_device_lock_init();

	/* Create the request queue */
	spin_lock_init(&nand_ops->queue_lock);
	INIT_LIST_HEAD(&nand_ops->rq_list);

	nand_ops->tag_set = kzalloc(sizeof(*nand_ops->tag_set), GFP_KERNEL);
	if (!nand_ops->tag_set) {
		ret = -ENOMEM;
		goto tag_set_error;
	}

	ret = blk_mq_alloc_sq_tag_set(nand_ops->tag_set, &rk_nand_mq_ops, 1,
				      BLK_MQ_F_SHOULD_MERGE | BLK_MQ_F_BLOCKING);
	if (ret)
		goto rq_init_error;

	INIT_LIST_HEAD(&nand_ops->devs);
	gc_task = kthread_run(nand_gc_thread, (void *)nand_ops, "rknand_gc");
	if (IS_ERR(gc_task)) {
		ret = PTR_ERR(gc_task);
		pr_err("failed to start GC thread: %d\n", ret);
		goto rq_init_error;
	}

	g_max_part_num = nand_parse_cmdline_part(disk_array);
	nand_ops->last_dev_index = 0;
	part.offset = 0;
	part.size = rk_ftl_get_capacity();
	part.type = 0;
	part.name[0] = 0;
	nand_add_dev(nand_ops, &part);

	if (g_max_part_num) {
		for (i = 0; i < g_max_part_num; i++) {
			u32 part_size = disk_array[i].offset + disk_array[i].size;

			pr_info("%10s: 0x%09llx -- 0x%09llx (%llu MB)\n",
				disk_array[i].name,
				(u64)disk_array[i].offset * 512,
				(u64)part_size * 512,
				(u64)disk_array[i].size / 2048);
			ret = nand_add_dev(nand_ops, &disk_array[i]);
			if (ret)
				pr_err("failed to add partition %s: %d\n",
				       disk_array[i].name, ret);
		}
	}

	rknand_create_procfs();
	rk_ftl_storage_sys_init();

	ret = rk_ftl_vendor_storage_init();
	if (!ret) {
		rk_vendor_register(rk_ftl_vendor_read, rk_ftl_vendor_write);
		rknand_vendor_storage_init();
		pr_info("rknand vendor storage init ok !\n");
	} else {
		pr_info("rknand vendor storage init failed !\n");
	}

	return 0;

rq_init_error:
	blk_mq_free_tag_set(nand_ops->tag_set);
	kfree(nand_ops->tag_set);
	nand_ops->tag_set = NULL;
tag_set_error:
	kfree(mtd_read_temp_buffer);
	mtd_read_temp_buffer = NULL;
mtd_buffer_error:
	unregister_blkdev(nand_ops->major, nand_ops->name);

	return ret;
}

static void nand_blk_unregister(struct nand_blk_ops *nand_ops)
{
	struct list_head *this, *next;

	if (!rk_nand_dev_initialised)
		return;
	nand_ops->quit = 1;
	wake_up(&nand_ops->thread_wq);
	wait_for_completion(&nand_ops->thread_exit);
	list_for_each_safe(this, next, &nand_ops->devs) {
		struct nand_blk_dev *dev
			= list_entry(this, struct nand_blk_dev, list);

		nand_remove_dev(dev);
	}
	blk_mq_free_tag_set(nand_ops->tag_set);
	kfree(nand_ops->tag_set);
	nand_ops->tag_set = NULL;
	unregister_blkdev(nand_ops->major, nand_ops->name);
}

void rknand_dev_flush(void)
{
	if (!rk_nand_dev_initialised)
		return;
	rknand_device_lock();
	rknand_ftl_flush_locked();
	rknand_device_unlock();
	pr_info("Nand flash flush ok!\n");
}

int __init rknand_dev_init(void)
{
	int ret;
	void __iomem *nandc0;
	void __iomem *nandc1;

	rknand_get_reg_addr((unsigned long *)&nandc0, (unsigned long *)&nandc1);
	if (!nandc0)
		return -1;

	ret = rk_ftl_init();
	if (ret) {
		pr_err("rk_ftl_init fail\n");
		return -1;
	}

	rknand_apply_bad_nand_policy();

	ret = nand_blk_register(&mytr);
	if (ret) {
		pr_err("nand_blk_register fail\n");
		return -1;
	}

	rk_nand_dev_initialised = 1;
	return ret;
}

int rknand_dev_exit(void)
{
	if (!rk_nand_dev_initialised)
		return -1;
	rk_nand_dev_initialised = 0;
	if (rknand_device_trylock()) {
		rknand_ftl_flush_locked();
		rknand_device_unlock();
	}
	nand_blk_unregister(&mytr);
	rk_ftl_de_init();
	pr_info("nand_blk_dev_exit:OK\n");
	return 0;
}

void rknand_dev_suspend(void)
{
	if (!rk_nand_dev_initialised)
		return;
	pr_info("rk_nand_suspend\n");
	rk_nand_schedule_enable_config(0);
	rknand_device_lock();
	rknand_ftl_flush_locked();
	rk_nand_suspend();
}

void rknand_dev_resume(void)
{
	if (!rk_nand_dev_initialised)
		return;
	pr_info("rk_nand_resume\n");
	rk_nand_resume();
	rknand_device_unlock();
	rk_nand_schedule_enable_config(1);
}

void rknand_dev_shutdown(void)
{
	pr_info("rknand_shutdown...\n");
	if (!rk_nand_dev_initialised)
		return;
	if (mytr.quit == 0) {
		mytr.quit = 1;
		wake_up(&mytr.thread_wq);
		wait_for_completion(&mytr.thread_exit);
		rknand_device_lock();
		rknand_ftl_flush_locked();
		rknand_device_unlock();
		rk_ftl_de_init();
	}
	pr_info("rknand_shutdown:OK\n");
}

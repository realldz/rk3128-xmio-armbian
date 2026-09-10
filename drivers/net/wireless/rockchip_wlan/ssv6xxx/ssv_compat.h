#ifndef _SSV_COMPAT_H_
#define _SSV_COMPAT_H_

#ifndef MODULE_SUPPORTED_DEVICE
#define MODULE_SUPPORTED_DEVICE(name)
#endif

#define timespec timespec64
#define getnstimeofday(ts) ktime_get_real_ts64(ts)
#define timespec_sub timespec64_sub
#define timespec_to_ns timespec64_to_ns

#endif

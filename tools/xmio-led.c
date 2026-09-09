/* xmio-led v20.2 — C daemon, replaces the shell script at the same path.
 * v20.1: fix gateway byte order from /proc/net/route (host-order hex,
 *        NOT network order — v20.0 pinged a byte-swapped address).
 *        + /tmp/xmio-led.log transition log.
 * v20.2: boot detect via lstat() — invocation symlinks are dangling,
 *        access() followed them and always failed (endless blink).
 *        Faster re-probe (2s) while waiting for DHCP.
 * RK3128 XMIO status LEDs:
 *   dual red/green @ gpio0_B0 (anti-parallel): brightness 1 = RED, 0 = GREEN
 *   yellow         @ gpio1_B1 (kernel-side ACTIVE_LOW): 1 = disk IO
 * Behavior: RED BLINK from service start until multi-user.target reached
 * AND network decided; then GREEN when global IPv4 + default GW answers
 * ICMP echo; RED otherwise. Yellow blinks on rknand_root sector delta.
 * Zero forks in steady state (getifaddrs + raw ICMP + /proc reads).
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <poll.h>
#include <time.h>
#include <stdarg.h>
#include <sys/socket.h>
#include <sys/stat.h>

#define TICK_MS 400
#define PING_EVERY 50   /* ticks: 20s between gateway pings */
#define MU_EVERY 4      /* ticks: 1.6s between multi-user checks */

static const char *P_STATUS, *P_YELLOW, *P_TRIG;

static void dlog(const char *fmt, ...); /* fwd: defined below */

static int wr(const char *path, int v)
{
	char buf[16];
	int n = snprintf(buf, sizeof buf, "%d\n", v);
	int fd = open(path, O_WRONLY);
	if (fd < 0)
		return -1;
	if (write(fd, buf, n) < 0) { }
	close(fd);
	return 0;
}

static int st_status = -1, st_yellow = -1;

static void set_status(int v)
{
	if (v != st_status) {
		if (wr(P_STATUS, v) == 0) {
			dlog("status -> %s", v ? "RED" : "GREEN");
			st_status = v;
		}
	}
}
static void set_yellow(int v)
{
	if (v != st_yellow) {
		if (wr(P_YELLOW, v) == 0) {
			st_yellow = v;
		}
	}
}

static double uptime_s(void)
{
	FILE *f = fopen("/proc/uptime", "r");
	double up = 0;
	if (!f)
		return 0;
	if (fscanf(f, "%lf", &up) != 1)
		up = 0;
	fclose(f);
	return up;
}

static int multiuser_reached(void)
{
	struct stat st;
	/* invocation symlinks are DANGLING (value = id string, not a path):
	 * access() follows and fails; lstat() does not follow. */
	if (lstat("/run/systemd/units/invocation:multi-user.target", &st) == 0)
		return 1;
	return uptime_s() >= 90.0; /* fallback if invocation links absent */
}

/* link = any non-excluded iface with IFF_RUNNING; *have_ip = global IPv4 */
static int net_probe(int *have_ip)
{
	struct ifaddrs *ifa = NULL, *p;
	int link = 0;
	*have_ip = 0;
	if (getifaddrs(&ifa) != 0)
		return 0;
	for (p = ifa; p; p = p->ifa_next) {
		const char *n;
		if (!p->ifa_name)
			continue;
		n = p->ifa_name;
		if (!strcmp(n, "lo"))
			continue;
		if (!strncmp(n, "sit", 3) || !strncmp(n, "tun", 3) ||
		    !strncmp(n, "virbr", 5))
			continue;
		if (p->ifa_flags & IFF_LOOPBACK)
			continue;
		if (p->ifa_flags & IFF_RUNNING)
			link = 1;
		if (p->ifa_addr && p->ifa_addr->sa_family == AF_INET) {
			struct sockaddr_in *a = (struct sockaddr_in *)p->ifa_addr;
			unsigned char *b = (unsigned char *)&a->sin_addr;
			if (!(b[0] == 169 && b[1] == 254) && b[0] < 224)
				*have_ip = 1;
		}
	}
	freeifaddrs(ifa);
	return link;
}

/* debug log: /tmp/xmio-led.log, transitions only (tmpfs, cleared per boot) */
static FILE *dbg = NULL;
static void dlog(const char *fmt, ...)
{
	if (!dbg)
		return;
	char up[32];
	FILE *u = fopen("/proc/uptime", "r");
	double us = 0;
	if (u) {
		if (fscanf(u, "%lf", &us) != 1)
			us = 0;
		fclose(u);
	}
	snprintf(up, sizeof up, "%.1f", us);
	va_list ap;
	fprintf(dbg, "[%s] ", up);
	va_start(ap, fmt);
	vfprintf(dbg, fmt, ap);
	va_end(ap);
	fprintf(dbg, "\n");
	fflush(dbg);
}

/* default gateway from /proc/net/route.
 * NOTE: gateway column is the u32 in HOST byte order rendering — on a
 * little-endian box 192.168.1.1 shows as 0101A8C0. Build the IP bytes
 * explicitly (LE of the parsed value) instead of any htonl() games. */
static int get_gw(struct in_addr *gw, char *gwstr, size_t gwsz)
{
	FILE *f = fopen("/proc/net/route", "r");
	char line[256];
	if (!f)
		return 0;
	while (fgets(line, sizeof line, f)) {
		char ifn[32];
		unsigned dest, g;
		if (sscanf(line, "%31s %x %x", ifn, &dest, &g) == 3 &&
		    dest == 0 && g != 0 && strcmp(ifn, "lo")) {
			unsigned char ipb[4];
			ipb[0] = g & 0xff;
			ipb[1] = (g >> 8) & 0xff;
			ipb[2] = (g >> 16) & 0xff;
			ipb[3] = (g >> 24) & 0xff;
			memcpy(&gw->s_addr, ipb, 4);
			snprintf(gwstr, gwsz, "%u.%u.%u.%u",
				 ipb[0], ipb[1], ipb[2], ipb[3]);
			fclose(f);
			return 1;
		}
	}
	fclose(f);
	return 0;
}

/* ICMP echo to gateway without fork; 1 = reply, 0 = timeout/dead, -1 = no socket */
static int ping_gw(struct in_addr dst)
{
	int s = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);
	int raw = 1;
	if (s < 0) {
		s = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
		raw = 0;
	}
	if (s < 0)
		return -1;
	char pkt[8];
	memset(pkt, 0, 8);
	static unsigned short idc = 0x3128;
	unsigned short id = idc++;
	unsigned short seq = 1;
	pkt[0] = 8; /* echo request */
	memcpy(pkt + 4, &id, 2);
	memcpy(pkt + 6, &seq, 2);
	unsigned sum = 0;
	for (int i = 0; i < 4; i++) {
		unsigned short v;
		memcpy(&v, pkt + 2 * i, 2);
		sum += v;
	}
	while (sum >> 16)
		sum = (sum & 0xffff) + (sum >> 16);
	unsigned short ck = ~(unsigned short)sum;
	memcpy(pkt + 2, &ck, 2);

	struct sockaddr_in sa;
	memset(&sa, 0, sizeof sa);
	sa.sin_family = AF_INET;
	sa.sin_addr = dst;
	if (sendto(s, pkt, 8, 0, (struct sockaddr *)&sa, sizeof sa) < 0) {
		close(s);
		return -1;
	}
	struct pollfd pfd = { .fd = s, .events = POLLIN };
	if (poll(&pfd, 1, 1000) > 0) {
		char rb[80];
		struct sockaddr_in from;
		socklen_t fl = sizeof from;
		ssize_t n = recvfrom(s, rb, sizeof rb, 0,
				     (struct sockaddr *)&from, &fl);
		int off = raw ? 20 : 0; /* raw includes IP header */
		if (n >= off + 8) {
			unsigned char *ic = (unsigned char *)rb + off;
			unsigned short rid;
			memcpy(&rid, ic + 4, 2);
			if (ic[0] == 0 && rid == id) {
				close(s);
				return 1;
			}
		}
	}
	close(s);
	return 0;
}

/* rknand_root sectors read/written (zero-fork /proc read) */
static void disk_sectors(unsigned long *rd, unsigned long *wr)
{
	FILE *f = fopen("/proc/diskstats", "r");
	char line[512], nm[64];
	unsigned long a, b, r, rm, rs, rt, w, wm, ws;
	*rd = *wr = 0;
	if (!f)
		return;
	while (fgets(line, sizeof line, f)) {
		if (sscanf(line, "%lu %lu %63s %lu %lu %lu %lu %lu %lu %lu",
			   &a, &b, nm, &r, &rm, &rs, &rt, &w, &wm, &ws) >= 10 &&
		    !strcmp(nm, "rknand_root")) {
			*rd = rs;
			*wr = ws;
			break;
		}
	}
	fclose(f);
}

int main(void)
{
	/* paths overridable for testing */
	P_STATUS = getenv("XLED_STATUS");
	P_YELLOW = getenv("XLED_YELLOW");
	P_TRIG   = getenv("XLED_TRIG");
	if (!P_STATUS) P_STATUS = "/sys/class/leds/xmio:red-green:status/brightness";
	if (!P_YELLOW) P_YELLOW = "/sys/class/leds/xmio:yellow:io/brightness";
	if (!P_TRIG)   P_TRIG   = "/sys/class/leds/xmio:red-green:status/trigger";

	int tf = open(P_TRIG, O_WRONLY);
	if (tf >= 0) {
		if (write(tf, "none\n", 5) < 0) { }
		close(tf);
	}
	if (access(P_STATUS, W_OK) || access(P_YELLOW, W_OK)) {
		fprintf(stderr, "xmio-led: LED nodes missing\n");
		return 1;
	}

	int netok = -1; /* -1 undecided, 1 connected, 0 not */
	int boot = 0, tick = 0, blink = 0, had_link = 0, have_disk = 0;
	unsigned long prd = 0, pwr = 0;
	int next_probe = 0;
	dbg = fopen("/tmp/xmio-led.log", "a");
	if (dbg)
		dlog("xmio-led-c v20.2 start");

	for (;;) {
		struct timespec ts = { 0, TICK_MS * 1000000L };
		nanosleep(&ts, NULL);
		tick++;

		if (!boot && (tick % MU_EVERY) == 0 && multiuser_reached()) {
			boot = 1;
			dlog("boot=1 (multi-user)");
		}

		int have_ip = 0;
		int link = net_probe(&have_ip);

		if (!link) {
			if (had_link)
				dlog("link lost -> netok=0");
			netok = 0;
			had_link = 0;
		} else {
			if (!had_link) { /* just got carrier: probe soon */
				dlog("link up (have_ip=%d) -> probing", have_ip);
				had_link = 1;
				netok = -1;
				tick = 0;
				next_probe = 0;
			}
			if (netok < 0 || tick >= next_probe) {
				int old = netok;
				if (!have_ip) {
					netok = 0;
					dlog("no global IP -> netok=0");
				} else {
					struct in_addr gw;
					char gws[32];
					if (get_gw(&gw, gws, sizeof gws)) {
						int pr = ping_gw(gw);
						netok = (pr == 1 || pr == -1) ? 1 : 0;
						dlog("ping gw=%s -> %s -> netok=%d",
						     gws, pr == 1 ? "reply" :
						     pr == -1 ? "socket-fail" :
							       "timeout", netok);
					} else {
						netok = 1; /* global IP, no default route */
						dlog("global IP, no default gw -> netok=1");
					}
				}
				if (old != -1 && old != netok)
					dlog("netok changed %d -> %d", old, netok);
				/* connected: recheck every 20s; undecided/missing
				 * IP: retry every 2s (waiting on DHCP) */
				next_probe = tick + (netok == 1 ? PING_EVERY : 5);
			}
		}

		if (!boot || netok < 0) {
			blink ^= 1;
			set_status(blink);          /* boot / deciding: red blink */
		} else if (netok == 1) {
			set_status(0);              /* connected: green */
		} else {
			set_status(1);              /* no link / no IP / gw dead: red */
		}

		unsigned long rd, wrr;
		disk_sectors(&rd, &wrr);
		if (rd || wrr) {
			if (!have_disk) {
				set_yellow(0);
				have_disk = 1;
			} else if (rd != prd || wrr != pwr) {
				set_yellow(1);
			} else {
				set_yellow(0);
			}
			prd = rd;
			pwr = wrr;
		} else {
			set_yellow(0);
		}
	}
	return 0;
}

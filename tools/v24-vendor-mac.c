// v24-vendor-mac.c — write LAN_MAC_ID (3) = B8:3D:4E:84:3D:A3 into
// Rockchip vendor storage via /dev/vendor_storage (RK_VENDOR_REQ ioctl).
// Build: arm-cross gcc -static. Verify by re-reading before/after.
// MAC can be overridden: argv[1] = "B8:3D:4E:84:3D:A3"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdint.h>
#include <sys/ioctl.h>

struct RK_VENDOR_REQ {
	uint32_t tag;
	uint16_t id;
	uint16_t len;
	uint8_t  data[1024];
};

#define VENDOR_REQ_TAG   0x56524551
#define VENDOR_READ_IO   _IOW('v', 0x01, uint32_t)
#define VENDOR_WRITE_IO  _IOW('v', 0x02, uint32_t)
#define LAN_MAC_ID       3

static int parse_mac(const char *s, uint8_t *out) {
	unsigned v[6];
	char extra;
	if (sscanf(s, "%02x:%02x:%02x:%02x:%02x:%02x%c",
	           &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &extra) != 6)
		return -1;
	for (int i = 0; i < 6; i++) out[i] = (uint8_t)v[i];
	return 0;
}

int main(int argc, char **argv) {
	uint8_t mac[6] = {0xB8, 0x3D, 0x4E, 0x84, 0x3D, 0xA3};
	int show_only = (argc > 1 && strcmp(argv[1], "show") == 0);
	if (!show_only && argc > 1 && parse_mac(argv[1], mac) != 0) {
		fprintf(stderr, "bad mac format: %s\n", argv[1]);
		return 2;
	}

	int fd = open("/dev/vendor_storage", O_RDWR);
	if (fd < 0) { perror("open /dev/vendor_storage"); return 1; }

	/* "show" = read LAN_MAC_ID only, print MAC or empty line (no write) */
	if (show_only) {
		struct RK_VENDOR_REQ req;
		memset(&req, 0, sizeof(req));
		req.tag = VENDOR_REQ_TAG;
		req.id  = LAN_MAC_ID;
		req.len = 1024;
		if (ioctl(fd, VENDOR_READ_IO, &req) == 0 && req.len == 6)
			printf("%02x:%02x:%02x:%02x:%02x:%02x\n",
			       req.data[0], req.data[1], req.data[2],
			       req.data[3], req.data[4], req.data[5]);
		else
			printf("\n");
		close(fd);
		return 0;
	}

	/* 1. read current LAN_MAC_ID */
	struct RK_VENDOR_REQ req;
	memset(&req, 0, sizeof(req));
	req.tag = VENDOR_REQ_TAG;
	req.id  = LAN_MAC_ID;
	req.len = 1024;
	if (ioctl(fd, VENDOR_READ_IO, &req) == 0 && req.len == 6)
		printf("current LAN_MAC_ID: %02x:%02x:%02x:%02x:%02x:%02x\n",
		       req.data[0], req.data[1], req.data[2],
		       req.data[3], req.data[4], req.data[5]);
	else
		printf("current LAN_MAC_ID: <empty or read failed> (len=%u errno=%s)\n",
		       req.len, strerror(errno));

	/* 2. write label MAC */
	memset(&req, 0, sizeof(req));
	req.tag = VENDOR_REQ_TAG;
	req.id  = LAN_MAC_ID;
	req.len = 6;
	memcpy(req.data, mac, 6);
	if (ioctl(fd, VENDOR_WRITE_IO, &req) != 0) {
		perror("VENDOR_WRITE_IO");
		close(fd);
		return 1;
	}
	printf("write ioctl OK\n");

	/* 3. read back to verify persistence path */
	memset(&req, 0, sizeof(req));
	req.tag = VENDOR_REQ_TAG;
	req.id  = LAN_MAC_ID;
	req.len = 1024;
	if (ioctl(fd, VENDOR_READ_IO, &req) == 0 && req.len == 6 &&
	    memcmp(req.data, mac, 6) == 0) {
		printf("verify OK: %02x:%02x:%02x:%02x:%02x:%02x stored in vendor storage\n",
		       req.data[0], req.data[1], req.data[2],
		       req.data[3], req.data[4], req.data[5]);
	} else {
		printf("verify FAILED (len=%u errno=%s) - write did not stick\n",
		       req.len, strerror(errno));
		close(fd);
		return 1;
	}
	close(fd);
	return 0;
}

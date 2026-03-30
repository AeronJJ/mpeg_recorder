#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <sys/mman.h>
#include <time.h>
#include <sys/sendfile.h>

#define BUF_SIZE 0x06400000

static const char* buffer0_loc = "/dev/mpeg_buf0";
static const char* buffer1_loc = "/dev/mpeg_buf1";

static const char* dump_irq_loc = "/dev/mpeg_buf_dump";

static int file_number = 0;
static const char* usb_loc = "/mnt/usb/";
static const char* file_suffix = "_dump.bin";

static int running = 1;

static uint8_t idle_mask = 0x01;
static uint8_t record_mask = 0x02;
static uint8_t playback_mask = 0x04;
static uint8_t buf0_mask = 0x08;
static uint8_t buf1_mask = 0x10;
static uint8_t playback_buf0_mask = 0x20;
static uint8_t playback_buf1_mask = 0x40;

static inline double timespec_to_sec(struct timespec *t) {
  return t->tv_sec + t->tv_nsec * 1e-9;
}

int record(uint8_t mask);
int dump_to_usb(const char* buffer, const char* filename);

int playback(uint8_t mask);
int load_from_usb(const char* buffer, const char* filename);

static void sigint_handler(int sig) {
  running = 0;
}
    
int main(void) {
  int fd;
  uint8_t mask;
  file_number = 0;
  
  signal(SIGINT, sigint_handler);
  
  fd = open(dump_irq_loc, O_RDONLY);
  if (fd < 0) {
    perror("Error opening /dev/mpeg_buf_dump");
    return 1;
  }
  
  printf("Waiting for interrupts...\n");

  int record_mode = 0;
  int playback_mode = 0;
  
  while (running) {
    ssize_t n = read(fd, &mask, 1);
    if (n < 0) {
      if (errno == EINTR) continue;
      perror("Error reading /dev/mpeg_buf_dump");
      break;
    }

    if (mask & idle_mask) {
      record_mode = 0;
      playback_mode = 0;
      file_number = 0;
    }
    else if (mask & record_mask) {
      record_mode = 1;
      playback_mode = 0;
      file_number = 0;
    }
    else if (mask & playback_mask) {
      record_mode = 0;
      playback_mode = 1;
      file_number = 0;
    }
    else {
      if (record_mode) {
	if (record(mask)) break;
      }
      else if (playback_mode) {
	int ret = playback(mask);
	if (ret == 1) { // Run out of files on USB
	  playback_mode = 0;
	}
	else if (ret == -1) { // Error
	  break;
	}	
      }
      else {
	continue;
      }
    }
  }

  close(fd);
  return 0;
}

int record(uint8_t mask) {
  // If both interrupts are triggered, don't dump either buffer as data will be corrupted
  if ((mask & buf0_mask) && (mask & buf1_mask)) {
    printf("Both interrupts detected, skipping\n");
    return 0;
  }
  else if (mask & buf0_mask) {// Dump buffer0
    printf("Interrupt Buffer0\n");
    char filename[256];
    snprintf(filename, sizeof(filename),
	     "%s%03d%s",
	     usb_loc,
	     file_number,
	     file_suffix);
    if (dump_to_usb(buffer0_loc, filename)) return -1;
    file_number++;
  }
  else if (mask & buf1_mask) { // Dump buffer1
    printf("Interrupt Buffer1\n");
    char filename[256];
    snprintf(filename, sizeof(filename),
	     "%s%03d%s",
	     usb_loc,
	     file_number,
	     file_suffix);
    if (dump_to_usb(buffer1_loc, filename)) return -1;
    file_number++;
  }
}

int dump_to_usb(const char* buffer, const char* filename) {
  printf("Dumping to USB (sendfile) %s\n", filename);

  // Open source buffer (memory-mapped file/device)
  int mem_fd = open(buffer, O_RDONLY);
  if (mem_fd < 0) { perror("open buffer"); return -1; }

  // Open destination USB file
  int usb_fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0666);
  if (usb_fd < 0) { perror("open usb file"); return -1; }

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);

  off_t offset = 0;
  ssize_t total = 0;

  while (total < BUF_SIZE) {
    ssize_t n = sendfile(usb_fd, mem_fd, &offset, BUF_SIZE - total);
    if (n <= 0) {
      perror("sendfile write");
      break;
    }
    total += n;
  }

  clock_gettime(CLOCK_MONOTONIC, &t1);

  double dt = timespec_to_sec(&t1) - timespec_to_sec(&t0);
  double mb = BUF_SIZE / (1024.0 * 1024.0);

  printf("Write time: %.3f s\n", dt);
  printf("Throughput: %.2f MB/s\n", mb / dt);
  printf("Transferred %zd bytes\n", total);

  close(mem_fd);
  close(usb_fd);

  return (total == BUF_SIZE) ? 0 : -1;
}

int playback(uint8_t mask) {
  if (mask & playback_buf0_mask) {
    printf("Interrupt Playback Buffer0\n");
    char filename[256];
    snprintf(filename, sizeof(filename),
	     "%s%03d%s",
	     usb_loc,
	     file_number,
	     file_suffix);
    if (access(filename, F_OK) == 0) {
      if (load_from_usb(buffer0_loc, filename)) return -1;
    }
    else {
      return 1;
    }
    file_number++;
  }
  if (mask & playback_buf1_mask) {
    printf("Interrupt Playback Buffer1\n");
    char filename[256];
    snprintf(filename, sizeof(filename),
	     "%s%03d%s",
	     usb_loc,
	     file_number,
	     file_suffix);
    if (access(filename, F_OK) == 0) {
      if (load_from_usb(buffer1_loc, filename)) return -1;
    }
    else {
      return 1;
    }
    file_number++;
  }
}

int load_from_usb(const char* buffer, const char* filename) {
  printf("Loading from USB (sendfile) %s\n", filename);

  // Open destination buffer (must be writable)
  int mem_fd = open(buffer, O_RDWR);
  if (mem_fd < 0) { perror("open buffer"); return -1; }

  // Open source USB file
  int usb_fd = open(filename, O_RDONLY);
  if (usb_fd < 0) { perror("open usb file"); return -1; }

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);

  off_t offset = 0;
  ssize_t total = 0;

  while (total < BUF_SIZE) {
    ssize_t n = sendfile(mem_fd, usb_fd, &offset, BUF_SIZE - total);
    if (n <= 0) {
      perror("sendfile read");
      break;
    }
    total += n;
  }

  clock_gettime(CLOCK_MONOTONIC, &t1);

  double dt = timespec_to_sec(&t1) - timespec_to_sec(&t0);
  double mb = BUF_SIZE / (1024.0 * 1024.0);

  printf("Read time: %.3f s\n", dt);
  printf("Throughput: %.2f MB/s\n", mb / dt);
  printf("Transferred %zd bytes\n", total);

  // Ensure data is visible to hardware
  fsync(mem_fd);

  close(mem_fd);
  close(usb_fd);

  return (total == BUF_SIZE) ? 0 : -1;
}

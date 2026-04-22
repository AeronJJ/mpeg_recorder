#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <sys/mman.h>
#include <time.h>
#include <sys/sendfile.h>

#define LW_BRIDGE_BASE  0xff200000
#define LW_BRIDGE_SPAN  0x00200000

#define REGS_OFFSET     0x00010000

#define BUF0_DONE_BIT   (1 << 0)
#define BUF1_DONE_BIT   (1 << 1)

volatile uint32_t *fpga_regs = NULL;

int init_fpga_regs() {
  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd < 0) {
    perror("open /dev/mem");
    return -1;
  }

  void *map = mmap(NULL, LW_BRIDGE_SPAN,
		   PROT_READ | PROT_WRITE,
		   MAP_SHARED,
		   fd,
		   LW_BRIDGE_BASE);

  close(fd);

  if (map == MAP_FAILED) {
    perror("mmap");
    return -1;
  }

  fpga_regs = (volatile uint32_t *)((uint8_t*)map + REGS_OFFSET);
  return 0;
}

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

  init_fpga_regs();
  
  printf("Waiting for interrupts...\n");

  int record_mode = 0;
  int playback_mode = 0;
  int playback_mask_delay = 0;
  
  while (running) {
    ssize_t n = read(fd, &mask, 1);
    if (n < 0) {
      if (errno == EINTR) continue;
      perror("Error reading /dev/mpeg_buf_dump");
      break;
    }

    if (mask & idle_mask) {
      printf("Idle_irq detected, Switching to Idle mode\n");
      record_mode = 0;
      playback_mode = 0;
      file_number = 0;
    }
    else if (mask & record_mask) {
      printf("Record_irq detected, Switching to Record mode\n");
      record_mode = 1;
      playback_mode = 0;
      file_number = 0;
    }
    else if (mask & playback_mask) {
      playback_mask_delay = mask;
      printf("Playback_irq detected, Switching to Playback mode\n");
      record_mode = 0;
      playback_mode = 1;
      file_number = 0;
    }
    else {
      if (record_mode) {
	if (record(mask)) break;
      }
      else if (playback_mode) {
	int ret = playback(mask | playback_mask_delay);
	if (playback_mask_delay) {
	  playback_mask_delay = 0;
	}
	if (ret == 1) { // Run out of files on USB
	  printf("Ran out of data on USB, disabling playback mode\n");
	  playback_mode = 0;
	}
	else if (ret == -1) { // Error
	  break;
	}	
      }
      else {
        sleep(1);
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
  return 0;
}

int dump_to_usb(const char* buffer, const char* filename) {
  printf("Dumping to USB (mmap) %s\n", filename);

  int mem_fd = open(buffer, O_RDONLY);
  if (mem_fd < 0) { perror("open buffer"); return -1; }

  int usb_fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, 0666);
  if (usb_fd < 0) { perror("open usb file"); close(mem_fd); return -1; }

  // Map FPGA memory
  void *fpga_ptr = mmap(NULL, BUF_SIZE, PROT_READ, MAP_SHARED, mem_fd, 0);
  if (fpga_ptr == MAP_FAILED) {
    perror("mmap");
    close(mem_fd);
    close(usb_fd);
    return -1;
  }

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);

  ssize_t total = 0;

  while (total < BUF_SIZE) {
    ssize_t n = write(usb_fd,
		      (char*)fpga_ptr + total,
		      BUF_SIZE - total);

    if (n < 0) {
      perror("write");
      break;
    }

    total += n;
  }

  // Ensure USB flush
  fsync(usb_fd);

  clock_gettime(CLOCK_MONOTONIC, &t1);

  double dt = timespec_to_sec(&t1) - timespec_to_sec(&t0);
  double mb = total / (1024.0 * 1024.0);

  printf("Write time: %.3f s\n", dt);
  printf("Throughput: %.2f MB/s\n", mb / dt);
  printf("Transferred %zd bytes\n", total);

  munmap(fpga_ptr, BUF_SIZE);
  close(mem_fd);
  close(usb_fd);

  return (total == BUF_SIZE) ? 0 : -1;
}

int playback(uint8_t mask) {
  fpga_regs[0] = 0;
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

      fpga_regs[0] = BUF0_DONE_BIT;
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

      fpga_regs[0] = BUF1_DONE_BIT;
    }
    else {
      return 1;
    }
    file_number++;
  }
  return 0;
}

int load_from_usb(const char* buffer, const char* filename) {
  printf("Loading from USB (mmap) %s\n", filename);

  int mem_fd = open(buffer, O_RDWR);
  if (mem_fd < 0) { perror("open buffer"); return -1; }

  int usb_fd = open(filename, O_RDONLY);
  if (usb_fd < 0) { perror("open usb file"); close(mem_fd); return -1; }

  void *fpga_ptr = mmap(NULL, BUF_SIZE, PROT_WRITE, MAP_SHARED, mem_fd, 0);
  if (fpga_ptr == MAP_FAILED) {
    perror("mmap");
    close(mem_fd);
    close(usb_fd);
    return -1;
  }

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);

  ssize_t total = 0;

  while (total < BUF_SIZE) {
    ssize_t n = read(usb_fd,
		     (char*)fpga_ptr + total,
		     BUF_SIZE - total);

    if (n < 0) {
      perror("read");
      break;
    }

    if (n == 0)
      break;  // EOF

    total += n;
  }

  // Ensure writes hit memory 
  msync(fpga_ptr, BUF_SIZE, MS_SYNC);

  clock_gettime(CLOCK_MONOTONIC, &t1);

  double dt = timespec_to_sec(&t1) - timespec_to_sec(&t0);
  double mb = total / (1024.0 * 1024.0);

  printf("Read time: %.3f s\n", dt);
  printf("Throughput: %.2f MB/s\n", mb / dt);
  printf("Transferred %zd bytes\n", total);

  munmap(fpga_ptr, BUF_SIZE);
  close(mem_fd);
  close(usb_fd);

  return (total == BUF_SIZE) ? 0 : -1;
}

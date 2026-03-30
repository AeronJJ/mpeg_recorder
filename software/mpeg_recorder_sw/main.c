#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <sys/mman.h>
#include <time.h>

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

void record(uint8_t mask);
int dump_to_usb(const char* buffer, const char* filename);

void playback(uint8_t mask);
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
	record(mask);
      }
      else if (playback_mode) {
	playback(mask);
      }
      else {
	continue;
      }
    }
  }

  close(fd);
  return 0;
}

void record(uint8_t mask) {
  // If both interrupts are triggered, don't dump either buffer as data will be corrupted
  if ((mask & buf0_mask) && (mask & buf1_mask)) {
    printf("Both interrupts detected, skipping\n");
    return;
  }
  else if (mask & buf0_mask) {// Dump buffer0
    printf("Interrupt Buffer0\n");
    char filename[256];
    snprintf(filename, sizeof(filename),
	     "%s%03d%s",
	     usb_loc,
	     file_number,
	     file_suffix);
    if (dump_to_usb(buffer0_loc, filename)) break;
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
    if (dump_to_usb(buffer1_loc, filename)) break;
    file_number++;
  }
}

int dump_to_usb(const char* buffer, const char* filename) {
  // Dumps contents of buffer to file on usb

  printf("Dumping to USB file %s\n", filename);

  // Open buffer
  int fd = open(buffer, O_RDONLY); // Read only
  if (fd < 0) { perror("Error opening buffer"); return -1; }

  uint32_t* buf = mmap(NULL, BUF_SIZE, PROT_READ, MAP_SHARED, fd, 0);
  if (buf == MAP_FAILED) { perror("Error creating mmap"); return -1; }

  // Open USB file
  FILE* usb_file = fopen(filename, "wb");
  if (!usb_file) { perror("Error opening usb"); return -1; }

  struct timespec t0, t1;

  clock_gettime(CLOCK_MONOTONIC, &t0);
  
  size_t n = fwrite(buf, 1, BUF_SIZE, usb_file);

  fflush(usb_file);

  clock_gettime(CLOCK_MONOTONIC, &t1);

  double dt = timespec_to_sec(&t1) - timespec_to_sec(&t0);
  double mb = BUF_SIZE / (1024.0 * 1024.0);

  printf("Write time: %.3f s\n", dt);
  printf("Throughput: %.2f MB/s\n", mb / dt);

  if (!n) { perror("No data written to usb"); return -1; }

  printf("Written %zu elements out of %d total\n", n, BUF_SIZE);
  fclose(usb_file);
  close(fd);

  return 0;
}

void playback(uint8_t mask) {
  if (mask & playback_buf0_mask) {
    printf("Interrupt Playback Buffer0\n");
    file_number++;
  }
  if (mask & playback_buf1_mask) {
    printf("Interrupt Playback Buffer1\n");
    
    file_number++;
  }
}

int load_from_usb(const char* buffer, const char* filename) {

}

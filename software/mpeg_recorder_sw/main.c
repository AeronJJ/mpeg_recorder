#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <unistd.h>
#include <time.h>

#define BUF_SIZE 0x06400000

static const char* buffer0_loc = "/dev/mpeg_buf0";
static const char* buffer1_loc = "/dev/mpeg_buf1";

static const char* usb_loc = "/mnt/";

static inline double timespec_to_sec(struct timespec *t)
{
    return t->tv_sec + t->tv_nsec * 1e-9;
}

int dump_to_usb(const char* buffer, const char* filename);

int main() {
  return dump_to_usb(buffer0_loc, "/mnt/usb/dump0.bin");
}


int dump_to_usb(const char* buffer, const char* filename) {
  // Dumps contents of buffer to file on usb

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

  /* size_t written = fwrite(buf, 1, BUF_SIZE, usb_file); */
  size_t n = fwrite(buf, 1, BUF_SIZE, usb_file);

  fflush(usb_file);

  clock_gettime(CLOCK_MONOTONIC, &t1);

  double dt = timespec_to_sec(&t1) - timespec_to_sec(&t0);
  double mb = BUF_SIZE / (1024.0 * 1024.0);

  printf("Write time: %.3f s\n", dt);
  printf("Throughput: %.2f MB/s\n", mb / dt);

  
  // Write to USB
  /* size_t n = fwrite(buf, 1, BUF_SIZE, usb_file); */
  if (!n) { perror("No data written to usb"); return -1; }

  printf("Written %zu elements out of %d total", n, BUF_SIZE);
  fclose(usb_file);
  close(fd);

  return 0;
}

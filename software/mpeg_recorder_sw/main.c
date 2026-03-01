#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>

#define BUF_SIZE 0x06400000

static const char* buffer0_loc = "/dev/mpeg_buf0";
static const char* buffer1_loc = "/dev/mpeg_buf1";

static const char* dump_irq_loc = "/dev/mpeg_buf_dump";

static int file_number = 0;
static const char* usb_loc = "/mnt/usb/";
static const char* file_suffix = "_dump.bin";

static int running = 1;

int dump_to_usb(const char* buffer, const char* filename);

static void sigint_handler(int sig) {
  running = 0;
}

static int usb_has_space(size_t required_bytes) {
  struct statvfs s;
  if (statvfs(usb_loc, &s) != 0) {
    perror("statvfs");
    return 0; // assume no space if we can't check
  }
  unsigned long long free_bytes = (unsigned long long)s.f_bavail * s.f_frsize;
  return free_bytes >= required_bytes;
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
  
  while (running) {
    ssize_t n = read(fd, &mask, 1);
    if (n < 0) {
      if (errno == EINTR) continue;
      perror("Error reading /dev/mpeg_buf_dump");
      break;
    }

    if (!usb_has_space(BUF_SIZE)) { // Might be redundant
      perror("Error - not enough free space on USB");
      break;
    }
    
    // If both interrupts are triggered, don't dump either buffer as data will be corrupted
    if (mask & 0x3) {
      continue;
    }
    else if (mask & 0x1) {// Dump buffer0
      char filename[256];
      snprintf(filename, sizeof(filename),
	       "%s%03d%s",
	       usb_loc,
	       file_number,
	       file_suffix);
      if (dump_to_usb(buffer0_loc, filename)) break;
      file_number++;
    }
    else if (mask & 0x2) { // Dump buffer1
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

  close(fd);
  return 0;
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

  // Write file
  size_t n = fwrite(buf, 1, BUF_SIZE, usb_file);

  fflush(usb_file);

  if (!n) { perror("No data written to usb"); return -1; }

  fclose(usb_file);
  close(fd);

  return 0;
}

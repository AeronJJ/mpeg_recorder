// mmap_stdio_vs_syscall_benchmark.c
//
// Benchmarks:
//
//   write()  vs fwrite()
//   read()   vs fread()
//
// using an mmap()'d FPGA-style buffer exactly like:
//
//   write(usb_fd, (char*)fpga_ptr + total, ...)
//   read(usb_fd,  (char*)fpga_ptr + total, ...)
//
// Build:
//   gcc -O2 -o mmap_bench mmap_stdio_vs_syscall_benchmark.c
//
// Example:
//   ./mmap_bench /dev/mem benchmark.bin 67108864
//
// Example with UIO/device buffer:
//   ./mmap_bench /dev/uio0 benchmark.bin 67108864

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/stat.h>

#define DEFAULT_SIZE   (64 * 1024 * 1024ULL)
#define CHUNK_SIZE     (64 * 1024)

static double diff_sec(struct timespec a, struct timespec b)
{
    return (b.tv_sec - a.tv_sec) +
           (b.tv_nsec - a.tv_nsec) / 1e9;
}

static void benchmark_write_syscall(
    int usb_fd,
    void *fpga_ptr,
    size_t size)
{
    printf("\n=== write() benchmark ===\n");

    lseek(usb_fd, 0, SEEK_SET);
    ftruncate(usb_fd, 0);

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    size_t total = 0;

    while (total < size) {

        size_t remaining = size - total;
        size_t chunk =
            remaining > CHUNK_SIZE ?
            CHUNK_SIZE : remaining;

        ssize_t n = write(
            usb_fd,
            (char*)fpga_ptr + total,
            chunk);

        if (n < 0) {
            perror("write");
            return;
        }

        total += n;
    }

    fsync(usb_fd);

    clock_gettime(CLOCK_MONOTONIC, &t1);

    double sec = diff_sec(t0, t1);
    double mbps = (size / (1024.0 * 1024.0)) / sec;

    printf("Transferred : %zu bytes\n", size);
    printf("Time         : %.6f s\n", sec);
    printf("Throughput   : %.2f MB/s\n", mbps);
}

static void benchmark_fwrite_stdio(
    const char *filename,
    void *fpga_ptr,
    size_t size)
{
    printf("\n=== fwrite() benchmark ===\n");

    FILE *f = fopen(filename, "wb");

    if (!f) {
        perror("fopen");
        return;
    }

    static char stdio_buf[1 << 20];

    setvbuf(
        f,
        stdio_buf,
        _IOFBF,
        sizeof(stdio_buf));

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    size_t total = 0;

    while (total < size) {

        size_t remaining = size - total;
        size_t chunk =
            remaining > CHUNK_SIZE ?
            CHUNK_SIZE : remaining;

        size_t n = fwrite(
            (char*)fpga_ptr + total,
            1,
            chunk,
            f);

        if (n != chunk) {
            perror("fwrite");
            fclose(f);
            return;
        }

        total += n;
    }

    fflush(f);
    fsync(fileno(f));

    clock_gettime(CLOCK_MONOTONIC, &t1);

    fclose(f);

    double sec = diff_sec(t0, t1);
    double mbps = (size / (1024.0 * 1024.0)) / sec;

    printf("Transferred : %zu bytes\n", size);
    printf("Time         : %.6f s\n", sec);
    printf("Throughput   : %.2f MB/s\n", mbps);
}

static void benchmark_read_syscall(
    int usb_fd,
    void *fpga_ptr,
    size_t size)
{
    printf("\n=== read() benchmark ===\n");

    lseek(usb_fd, 0, SEEK_SET);

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    size_t total = 0;

    while (total < size) {

        size_t remaining = size - total;
        size_t chunk =
            remaining > CHUNK_SIZE ?
            CHUNK_SIZE : remaining;

        ssize_t n = read(
            usb_fd,
            (char*)fpga_ptr + total,
            chunk);

        if (n < 0) {
            perror("read");
            return;
        }

        if (n == 0)
            break;

        total += n;
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);

    double sec = diff_sec(t0, t1);
    double mbps = (total / (1024.0 * 1024.0)) / sec;

    printf("Transferred : %zu bytes\n", total);
    printf("Time         : %.6f s\n", sec);
    printf("Throughput   : %.2f MB/s\n", mbps);
}

static void benchmark_fread_stdio(
    const char *filename,
    void *fpga_ptr,
    size_t size)
{
    printf("\n=== fread() benchmark ===\n");

    FILE *f = fopen(filename, "rb");

    if (!f) {
        perror("fopen");
        return;
    }

    static char stdio_buf[1 << 20];

    setvbuf(
        f,
        stdio_buf,
        _IOFBF,
        sizeof(stdio_buf));

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    size_t total = 0;

    while (total < size) {

        size_t remaining = size - total;
        size_t chunk =
            remaining > CHUNK_SIZE ?
            CHUNK_SIZE : remaining;

        size_t n = fread(
            (char*)fpga_ptr + total,
            1,
            chunk,
            f);

        if (n == 0) {
            if (ferror(f))
                perror("fread");
            break;
        }

        total += n;
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);

    fclose(f);

    double sec = diff_sec(t0, t1);
    double mbps = (total / (1024.0 * 1024.0)) / sec;

    printf("Transferred : %zu bytes\n", total);
    printf("Time         : %.6f s\n", sec);
    printf("Throughput   : %.2f MB/s\n", mbps);
}

static void drop_cache(void)
{
    sync();

    FILE *f = fopen("/proc/sys/vm/drop_caches", "w");

    if (!f) {
        perror("drop_caches");
        return;
    }

    fprintf(f, "3\n");

    fclose(f);
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr,
            "Usage: %s <buffer_device> <file> [size]\n",
            argv[0]);
        return 1;
    }

    const char *buffer   = argv[1];
    const char *filename = argv[2];

    size_t size =
        (argc >= 4) ?
        strtoull(argv[3], NULL, 0) :
        DEFAULT_SIZE;

    printf("Buffer device : %s\n", buffer);
    printf("File          : %s\n", filename);
    printf("Transfer size : %zu bytes (%.2f MiB)\n",
           size,
           size / (1024.0 * 1024.0));

    //
    // WRITE BENCHMARK SETUP
    //

    int mem_fd = open(buffer, O_RDWR);

    if (mem_fd < 0) {
        perror("open buffer");
        return 1;
    }

    int usb_fd = open(
        filename,
        O_RDWR | O_CREAT | O_TRUNC,
        0666);

    if (usb_fd < 0) {
        perror("open file");
        close(mem_fd);
        return 1;
    }

    void *fpga_ptr = mmap(
        NULL,
        size,
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        mem_fd,
        0);

    if (fpga_ptr == MAP_FAILED) {
        perror("mmap");
        close(mem_fd);
        close(usb_fd);
        return 1;
    }

    //
    // Fill mmap buffer with pattern
    //

    for (size_t i = 0; i < size; i++) {
        ((uint8_t*)fpga_ptr)[i] = i & 0xFF;
    }

    //
    // WRITE TESTS
    //

    benchmark_write_syscall(
        usb_fd,
        fpga_ptr,
        size);

    drop_cache();

    benchmark_fwrite_stdio(
        filename,
        fpga_ptr,
        size);

    drop_cache();

    //
    // READ TESTS
    //

    memset(fpga_ptr, 0, size);

    benchmark_read_syscall(
        usb_fd,
        fpga_ptr,
        size);

    drop_cache();

    memset(fpga_ptr, 0, size);

    benchmark_fread_stdio(
        filename,
        fpga_ptr,
        size);

    munmap(fpga_ptr, size);

    close(mem_fd);
    close(usb_fd);

    return 0;
}

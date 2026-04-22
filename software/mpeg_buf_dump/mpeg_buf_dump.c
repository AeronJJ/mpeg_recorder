#include <linux/module.h>
#include <linux/init.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/uaccess.h>
#include <linux/wait.h>
#include <linux/spinlock.h>

#define DEVICE_NAME "mpeg_buf_dump"
#define CLASS_NAME  "mpeg_dump"

// FPGA IRQs:
//   72: Idle
//   73: Record
//   74: Playback
//   75: Record Buf0 Full
//   76: Record Buf1 Full
//   77: Playback Buf0 Req
//   78: Playback Buf1 Req

static int irq_idle = 72;
static int irq_record = 73;
static int irq_playback = 74;
static int irq_buf0 = 75;
static int irq_buf1 = 76;
static int irq_playback_buf0 = 77;
static int irq_playback_buf1 = 78;

static uint8_t idle_mask = 0x01;
static uint8_t record_mask = 0x02;
static uint8_t playback_mask = 0x04;
static uint8_t buf0_mask = 0x08;
static uint8_t buf1_mask = 0x10;
static uint8_t playback_buf0_mask = 0x20;
static uint8_t playback_buf1_mask = 0x40;

static dev_t dev_num;
static struct cdev mpeg_dump_cdev;
static struct class *mpeg_dump_class;
static struct device *mpeg_dump_device;

// Bitmask latch
static uint8_t pending_mask = 0;

static irqreturn_t idle_isr(int irq, void *dev_id) {
  pending_mask |= idle_mask;
  return IRQ_HANDLED;
}

static irqreturn_t record_isr(int irq, void *dev_id) {
  pending_mask |= record_mask;
  return IRQ_HANDLED;
}

static irqreturn_t playback_isr(int irq, void *dev_id) {
  pending_mask |= playback_mask;
  return IRQ_HANDLED;
}

static irqreturn_t buf0_isr(int irq, void *dev_id) {
  pending_mask |= buf0_mask;
  return IRQ_HANDLED;
}

static irqreturn_t buf1_isr(int irq, void *dev_id) {
  pending_mask |= buf1_mask;
  return IRQ_HANDLED;
}

static irqreturn_t playback_buf0_isr(int irq, void *dev_id) {
  pending_mask |= playback_buf0_mask;
  return IRQ_HANDLED;
}

static irqreturn_t playback_buf1_isr(int irq, void *dev_id) {
  pending_mask |= playback_buf1_mask;
  return IRQ_HANDLED;
}

static ssize_t mpeg_dump_read(struct file *file, char __user *buf, size_t count, loff_t *ppos) {
  uint8_t mask;

  if (count < 1)
    return -EINVAL;
    
  mask = pending_mask;
  pending_mask = 0;   // clear all bits that userspace will handle

  if (copy_to_user(buf, &mask, 1))
    return -EFAULT;

  return 1;
}

static const struct file_operations mpeg_dump_fops = {
  .owner = THIS_MODULE,
  .read  = mpeg_dump_read,
};

static int __init mpeg_dump_init(void) {
  int ret;

  ret = alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);
  if (ret) return ret;

  cdev_init(&mpeg_dump_cdev, &mpeg_dump_fops);
  cdev_add(&mpeg_dump_cdev, dev_num, 1);

  mpeg_dump_class = class_create(THIS_MODULE, CLASS_NAME);
  mpeg_dump_device = device_create(mpeg_dump_class, NULL, dev_num, NULL, DEVICE_NAME);

  ret = request_irq(irq_idle, idle_isr, 0, "mpeg_buf_dump", NULL);
  if (ret) return ret;
  ret = request_irq(irq_record, record_isr, 0, "mpeg_buf_dump", NULL);
  if (ret) return ret;
  ret = request_irq(irq_playback, playback_isr, 0, "mpeg_buf_dump", NULL);
  if (ret) return ret;
  ret = request_irq(irq_buf0, buf0_isr, 0, "mpeg_buf_dump", NULL);
  if (ret) return ret;
  ret = request_irq(irq_buf1, buf1_isr, 0, "mpeg_buf_dump", NULL);
  if (ret) return ret;
  ret = request_irq(irq_playback_buf0, playback_buf0_isr, 0, "mpeg_buf_dump", NULL);
  if (ret) return ret;
  ret = request_irq(irq_playback_buf1, playback_buf1_isr, 0, "mpeg_buf_dump", NULL);
  if (ret) return ret;

  return 0;
}

static void __exit mpeg_dump_exit(void) {
  free_irq(irq_idle, NULL);
  free_irq(irq_record, NULL);
  free_irq(irq_playback, NULL);
  free_irq(irq_buf0, NULL);
  free_irq(irq_buf1, NULL);
  free_irq(irq_playback_buf0, NULL);
  free_irq(irq_playback_buf1, NULL);
  device_destroy(mpeg_dump_class, dev_num);
  class_destroy(mpeg_dump_class);
  cdev_del(&mpeg_dump_cdev);
  unregister_chrdev_region(dev_num, 1);
}

module_init(mpeg_dump_init);
module_exit(mpeg_dump_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Aeron Jarvis");
MODULE_DESCRIPTION("MPEG Dump Interrupt Handler");

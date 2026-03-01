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

static int irq_buf0 = 75;
static int irq_buf1 = 76;

static dev_t dev_num;
static struct cdev mpeg_dump_cdev;
static struct class *mpeg_dump_class;
static struct device *mpeg_dump_device;

static wait_queue_head_t event_wq;
static spinlock_t latch_lock;

// Bitmask latch: bit0 = buf0, bit1 = buf1
static uint8_t pending_mask = 0;

static irqreturn_t buf0_isr(int irq, void *dev_id) {
    unsigned long flags;
    spin_lock_irqsave(&latch_lock, flags);
    pending_mask |= 0x1;
    spin_unlock_irqrestore(&latch_lock, flags);
    wake_up_interruptible(&event_wq);
    return IRQ_HANDLED;
}

static irqreturn_t buf1_isr(int irq, void *dev_id) {
    unsigned long flags;
    spin_lock_irqsave(&latch_lock, flags);
    pending_mask |= 0x2;
    spin_unlock_irqrestore(&latch_lock, flags);
    wake_up_interruptible(&event_wq);
    return IRQ_HANDLED;
}

static ssize_t mpeg_dump_read(struct file *file, char __user *buf, size_t count, loff_t *ppos) {
    uint8_t mask;
    unsigned long flags;
    int ret;

    if (count < 1)
        return -EINVAL;

    // Block until at least one bit is set
    ret = wait_event_interruptible(event_wq, pending_mask != 0);
    if (ret)
        return ret;

    spin_lock_irqsave(&latch_lock, flags);
    mask = pending_mask;
    pending_mask = 0;   // clear all bits that userspace will handle
    spin_unlock_irqrestore(&latch_lock, flags);

    if (copy_to_user(buf, &mask, 1))
        return -EFAULT;

    return 1;
}

static const struct file_operations mpeg_dump_fops = {
    .owner = THIS_MODULE,
    .read  = mpeg_dump_read,
};

static int __init mpeg_dump_init(void)
{
    int ret;

    init_waitqueue_head(&event_wq);
    spin_lock_init(&latch_lock);

    ret = alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);
    if (ret) return ret;

    cdev_init(&mpeg_dump_cdev, &mpeg_dump_fops);
    cdev_add(&mpeg_dump_cdev, dev_num, 1);

    mpeg_dump_class = class_create(THIS_MODULE, CLASS_NAME);
    mpeg_dump_device = device_create(mpeg_dump_class, NULL, dev_num, NULL, DEVICE_NAME);

    request_irq(irq_buf0, buf0_isr, 0, "mpeg_dump_buf0", NULL);
    request_irq(irq_buf1, buf1_isr, 0, "mpeg_dump_buf1", NULL);

    return 0;
}

static void __exit mpeg_dump_exit(void)
{
    free_irq(irq_buf0, NULL);
    free_irq(irq_buf1, NULL);
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

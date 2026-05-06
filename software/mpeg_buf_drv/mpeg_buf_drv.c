#include <linux/module.h>
#include <linux/init.h>
#include <linux/of.h>
#include <linux/io.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/mm.h>

#define NUM_BUFFERS 2

static const char *buf_names[NUM_BUFFERS] = {"mpeg_buf0", "mpeg_buf1"};
static const char *dt_names[NUM_BUFFERS] = {"buffer0", "buffer1"};

static void __iomem *buf_virt[NUM_BUFFERS];
static u32 buf_phys[NUM_BUFFERS];
static u32 buf_size[NUM_BUFFERS];

static dev_t devt;
static struct cdev cdev[NUM_BUFFERS];
static struct class *cls;

/* mmap callback */
static int mpeg_buf_mmap(struct file *filp, struct vm_area_struct *vma) {
  int idx = (int)(uintptr_t)filp->private_data;
  unsigned long pfn = buf_phys[idx] >> PAGE_SHIFT;
  unsigned long size = vma->vm_end - vma->vm_start;

  if (size > buf_size[idx])
    return -EINVAL;

  if (remap_pfn_range(vma, vma->vm_start, pfn, size, vma->vm_page_prot))
    return -EAGAIN;

  return 0;
}

/* open callback: store buffer index in file->private_data */
static int mpeg_buf_open(struct inode *inode, struct file *filp) {
  int idx = iminor(inode); // minor number corresponds to buffer index
  filp->private_data = (void *)(uintptr_t)idx;
  return 0;
}

static struct file_operations fops = {
  .owner = THIS_MODULE,
  .open  = mpeg_buf_open,
  .mmap  = mpeg_buf_mmap,
};

/* Module init */
static int __init mpeg_buf_init(void) {
  struct device_node *np;
  const __be32 *prop;
  int i, ret;

  printk(KERN_INFO "=== MPEG Buffer Driver Init ===\n");

  ret = alloc_chrdev_region(&devt, 0, NUM_BUFFERS, "mpeg_buf");
  if (ret) {
    printk(KERN_ERR "Failed to allocate chrdev region\n");
    return ret;
  }

  cls = class_create(THIS_MODULE, "mpeg_buf_class");
  if (IS_ERR(cls)) {
    unregister_chrdev_region(devt, NUM_BUFFERS);
    return PTR_ERR(cls);
  }

  for (i = 0; i < NUM_BUFFERS; i++) {
    np = of_find_node_by_name(NULL, dt_names[i]);
    if (!np) {
      printk(KERN_ERR "%s node not found!\n", dt_names[i]);
      continue;
    }

    prop = of_get_property(np, "reg", NULL);
    if (!prop) {
      printk(KERN_ERR "Failed to get reg for %s\n", dt_names[i]);
      continue;
    }

    buf_phys[i] = be32_to_cpu(prop[0]);
    buf_size[i] = be32_to_cpu(prop[1]);

    buf_virt[i] = ioremap(buf_phys[i], buf_size[i]);
    if (!buf_virt[i]) {
      printk(KERN_ERR "Failed to ioremap %s\n", dt_names[i]);
      continue;
    }

    cdev_init(&cdev[i], &fops);
    cdev[i].owner = THIS_MODULE;

    ret = cdev_add(&cdev[i], devt + i, 1);
    if (ret) {
      printk(KERN_ERR "Failed to add cdev %s\n", buf_names[i]);
      continue;
    }

    device_create(cls, NULL, devt + i, NULL, buf_names[i]);

    printk(KERN_INFO "%s mapped: phys=0x%08x size=0x%08x\n",
	   buf_names[i], buf_phys[i], buf_size[i]);
  }

  return 0;
}

/* Module exit */
static void __exit mpeg_buf_exit(void) {
  int i;

  for (i = 0; i < NUM_BUFFERS; i++) {
    device_destroy(cls, devt + i);
    cdev_del(&cdev[i]);
    if (buf_virt[i])
      iounmap(buf_virt[i]);
  }

  class_destroy(cls);
  unregister_chrdev_region(devt, NUM_BUFFERS);

  printk(KERN_INFO "=== MPEG Buffer Driver Exit ===\n");
}

module_init(mpeg_buf_init);
module_exit(mpeg_buf_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Aeron Jarvis");
MODULE_DESCRIPTION("MPEG DDR3 Buffer Driver with mmap for user space");


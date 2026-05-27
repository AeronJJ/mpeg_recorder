### Instructions for use
- Turn on DE1-SoC Board using red power button
- Connect mini USB cable from DE1-SoC to host PC
- Use Serial/UART tool (such as Putty or Screen) to connect to DE1-SoC (baud rate of 115200)
- Plug USB storage device into DE1-SoC
- Send ./load.sh command over serial connection
- Select relevant mode on touch screen
  - If recording, press physical button1 on DE1-SoC board to start the recording
- Watch serial communication for interrupt progress, if no change after ~30 seconds, press physical button0 on DE1-SoC board to perform FPGA reset

### Setup Details (only need to do once)
- Acquire Linux image from [Intel Website](https://www.intel.com/content/www/us/en/developer/topic-technology/fpga-academic/materials-sd-card-images.html)
- Load Linux image onto SD card using Balena Etcher or equivalent
- Compile Quartus Project to generate .sof bitstream
- Acquire Intel FPGA Embedded Command Shell Tools from Embedded Development Suite
- Use Embedded Command Shell `quartus_cpf` command to convert .sof into .rbf file:
  `quartus_cpf -c -o bitstream_compression=on MPEG_RECORDER.sof bitstream.rbf`
- Copy .rbf file to SD Card, overwriting default file
- Copy `./software/device_tree/socfgpa.dtb` file to SD card, overwriting default .dtb file
- Copy `./software/mpeg_buf_drv`, `./software/mpeg_buf_dump`, `./software/mpeg_recorder_sw` folders to Documents folder on SD card
- Put SD card into DE1-SoC
- Set MSEL[4:0] switches to 01010 to boot Linux from SD card
- Turn on DE1-SoC board
- Connect to board over Serial/UART connection using tool such as Putty or Screen (baud rate of 115200)
- Run Make in each of the following folders:
  - `~/Documents/mpeg_buf_drv/`
  - `~/Documents/mpeg_buf_dump/`
  - `~/Documents/mpeg_recorder_sw/`
  - Or wherever folders were moved to
- Load kernel drivers using insmod:
  - `sudo insmod ~/Documents/mpeg_buf_drv/mpeg_buf_drv`
  - `sudo insmod ~/Documents/mpeg_buf_dump/mpeg_buf_dump`
- Insert USB Storage Device into DE1-SoC and mount to /mnt/usb:
  - `mount /dev/sda1 /mnt/usb` (example - exact command may vary)
- Run recorder software:
  - `./~/Documents/mpeg_recorder_sw/main`

### Project Env
Bring project commands into terminal session, from project root:
```
source project_setup.sh
```

#### Generating Designs and Testbench
Generate new SystemVerilog module:
```
mpeg_gen_design MODULE_NAME
```

Generate testbench from design:
```
mpeg_gen_tb MODULE_NAME
```

### Run Testbench
From MODULE_NAME/sim:
```
mpeg_verilator [-vcd VCD_FILE] MODULE_NAME_tb
```

Use `[-vcd VCD_FILE]` to specify a vcd file to use to generate signal stimuli.
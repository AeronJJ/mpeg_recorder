### Instructions for use
- Turn on DE1-SoC Board using red power button
- Connect mini USB cable from DE1-SoC to host PC
- Use Serial/UART tool (such as Putty or Screen) to connect to DE1-SoC (baud rate of 115200)
- Plug USB storage device into DE1-SoC
- Send ./load.sh command over serial connection
- Select relevant mode on touch screen
  - If recording, press physical button1 on DE1-SoC board to start the recording
- Watch serial communication for interrupt progress, if no change after ~30 seconds, press physical button0 on DE1-SoC board to perform FPGA reset



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
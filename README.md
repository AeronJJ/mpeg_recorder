
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
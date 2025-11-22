mpeg_verilator() {
    # verilator -f $1.f --trace --timescale 1ns/100ps --binary $1.sv  && \
    verilator --trace --timescale 1ns/100ps --binary $1.sv -y ../hdl && \
    ./obj_dir/V$1 && \
    gtkwave waves.vcd &
}

mpeg_gen_design() { # Must use from /MPEG/src/
    python ../scripts/gen_design.py $1
}

mpeg_gen_tb() { # Must ust from /MPEG/src/DESIGN
    python ../../scripts/gen_tb.py $1 $2
}

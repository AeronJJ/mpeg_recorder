PROJ_ROOT="$PWD"

mpeg_verilator() {
    # verilator -f $1.f --trace --timescale 1ns/100ps --binary $1.sv  && \
    verilator --trace --timescale 1ns/100ps --binary $1.sv -y ../hdl && \
    ./obj_dir/V$1 && \
    gtkwave waves.vcd &
}

mpeg_gen_design() { # Must use from /MPEG/src/
    if [ "$1" == "-h" ]; then
	echo "Usage: mpeg_gen_design name1"
	echo "Must be used from $PROJ_ROOT/src/"
    else
	python ../scripts/gen_design.py $@
    fi
}

mpeg_gen_tb() { # Must ust from /MPEG/src/DESIGN
    if [ "$1" == "-h" ]; then
	echo "Usage: mpeg_gen_tb [-h] name [-v]"
	echo "Must be used from $PROJ_ROOT/src/"
    else
	python ../../scripts/gen_tb.py $@
    fi
}

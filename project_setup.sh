PROJ_ROOT="$PWD"
VCD2V="$PROJ_ROOT/scripts/vcd2v/target/debug/vcd2v"
MERGE_SV="$PROJ_ROOT/scripts/merge_sv.py"
GEN_TB="$PROJ_ROOT/scripts/gen_tb.py"
GEN_DESIGN="$PROJ_ROOT/scripts/gen_design.py"

mpeg_verilator() {
    if [ "$1" == "-vcd" ]; then
	tmp_data=$(mktemp)
	$VCD2V -i $2 --time :24000000 --scale 0.1 -f 6 -m vcd_signal_map.sm > $tmp_data.sv
	tmp_tb=$(mktemp)

	if ! python $MERGE_SV -t $3.sv -s $tmp_data.sv -o $tmp_tb.sv; then
	    echo "merge_sv.py failed"
	# elif ! verilator --coverage --assert --trace --debug --timescale 1ns/100ps -CFLAGS "-g -O0" -LDFLAGS "-fsanitize=address" --binary $tmp_tb.sv -y ../hdl; then
	elif ! verilator --coverage --trace --timescale 1ns/100ps --binary $tmp_tb.sv -y ../hdl; then
	    echo "verilator failed"
	elif ! ./obj_dir/Vtmp; then
	    echo "Verilated program failed"
	else
 	    gtkwave waves.vcd &
	fi
	rm $tmp_data.sv $tmp_tb.sv
    else
	verilator -Wall --coverage --trace --timescale 1ns/100ps --binary $1.sv -y ../hdl && \
	    ./obj_dir/V$1 && \
	    gtkwave waves.vcd &	
    fi
}

mpeg_gen_design() { # Must use from /MPEG/src/
    if [ "$1" == "-h" ]; then
	echo "Usage: mpeg_gen_design name1"
	echo "Must be used from $PROJ_ROOT/src/"
    else
	cd $PROJ_ROOT/src/ && \
	python $GEN_DESIGN $@
    fi
}

mpeg_gen_tb() { # Must use from /MPEG/src/DESIGN
    if [ "$1" == "-h" ]; then
	echo "Usage: mpeg_gen_tb [-h] name [-v]"
	echo "Must be used from $PROJ_ROOT/src/DESIGN"
    else
	cd $PROJ_ROOT/src/$1 && \
	python $GEN_TB $@
    fi
}

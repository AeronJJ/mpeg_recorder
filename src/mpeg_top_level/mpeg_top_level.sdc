create_clock -name mpeg_clk_6MHz -period 166.667 [get_ports mpeg_clk_6MHz]

create_generated_clock -name mpeg_clk_6MHz_out \
    -source [get_ports mpeg_clk_6MHz] \
    [get_ports mpeg_clk_6MHz_out]

set_false_path -from [get_ports rst_n]

# create_generated_clock -name clk_3MHz \
#     -source [get_ports mpeg_clk_6MHz] \
#     -divide_by 2 \
#     [get_nets {mpeg_mpeg_recorder_0|clk_3MHz}]

# create_generated_clock -name clk_1M5Hz \
#     -source [get_nets {mpeg_mpeg_recorder_0|clk_3MHz}] \
#     -divide_by 2 \
#     [get_nets {mpeg_mpeg_recorder_0|clk_1M5Hz}]

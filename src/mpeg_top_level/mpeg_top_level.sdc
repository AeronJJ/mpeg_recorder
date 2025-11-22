create_clock -name mpeg_clk_6MHz -period 166.667 [get_ports mpeg_clk_6MHz]

create_generated_clock -name mpeg_clk_6MHz_out \
    -source [get_ports mpeg_clk_6MHz] \
    [get_ports mpeg_clk_6MHz_out]
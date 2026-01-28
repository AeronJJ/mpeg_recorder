create_clock -name ref_clk_50MHz -period 20 [get_ports ref_clk_50MHz]

derive_pll_clocks

create_clock -name mpeg_clk_6MHz -period 166.667 [get_ports mpeg_clk_6MHz]

create_generated_clock -name mpeg_clk_6MHz_out \
    -source [get_ports mpeg_clk_6MHz] \
    [get_ports mpeg_clk_6MHz_out]

set_false_path -from [get_ports rst_n]
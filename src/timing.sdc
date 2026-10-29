create_clock -name clk50 -period 20 [get_ports {clk}]
derive_pll_clocks -gen_basic_clock
set_false_path -from [get_ports {sw0_n}]
set_false_path -from [get_ports {sd_miso}]

# Matrix input pads feed a two-stage synchronizer.
set_false_path -from [get_ports {key_col[*]}]

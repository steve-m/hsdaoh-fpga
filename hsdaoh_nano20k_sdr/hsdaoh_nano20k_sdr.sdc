create_clock -name sys_clk -period 37.04  [get_ports {sys_clk}] -add
create_clock -name adc_clkout -period 11.11  [get_ports {adc_clkout}] -add
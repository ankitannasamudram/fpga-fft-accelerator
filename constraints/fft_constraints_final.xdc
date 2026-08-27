# Add board clock and I/O constraints after board bring-up.
## 100 MHz clock
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]


## Start button
set_property PACKAGE_PIN N17 [get_ports btn_start]
set_property IOSTANDARD LVCMOS33 [get_ports btn_start]


## Reset button
set_property PACKAGE_PIN P18 [get_ports btn_reset]
set_property IOSTANDARD LVCMOS33 [get_ports btn_reset]


## Start LED
set_property PACKAGE_PIN H17 [get_ports led_start]
set_property IOSTANDARD LVCMOS33 [get_ports led_start]


## Busy LED
set_property PACKAGE_PIN K15 [get_ports led_busy]
set_property IOSTANDARD LVCMOS33 [get_ports led_busy]


## Done LED
set_property PACKAGE_PIN J13 [get_ports led_done]
set_property IOSTANDARD LVCMOS33 [get_ports led_done]


## USB-UART
## PC to FPGA
## Board schematic name UART_TXD_IN
set_property PACKAGE_PIN C4 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]


## FPGA to PC
## Board schematic name UART_RXD_OUT
set_property PACKAGE_PIN D4 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property PACKAGE_PIN Y11  [get_ports {cs}];    # JA1 pin
set_property PACKAGE_PIN AA11 [get_ports {wr}];    # JA2 pin
set_property PACKAGE_PIN Y10  [get_ports {data}];  # JA3 pin

set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 13]];


set_instance_assignment -name IO_STANDARD "2.5 V" -to CLK

set_instance_assignment -name IO_STANDARD "1.5 V SCHMITT TRIGGER" -to NRST

set_instance_assignment -name IO_STANDARD "1.2 V" -to LED[0]
set_instance_assignment -name IO_STANDARD "1.2 V" -to LED[1]
set_instance_assignment -name IO_STANDARD "1.2 V" -to LED[2]
set_instance_assignment -name IO_STANDARD "1.2 V" -to LED[3]
set_instance_assignment -name IO_STANDARD "1.2 V" -to LED[4]
set_instance_assignment -name IO_STANDARD "1.2 V" -to LED[5]
set_instance_assignment -name IO_STANDARD "1.2 V" -to LED[6]
set_instance_assignment -name IO_STANDARD "1.2 V" -to LED[7]

set_instance_assignment -name IO_STANDARD "1.2 V" -to USB_CLKIN
set_instance_assignment -name IO_STANDARD "1.5 V" -to USB_CLKOUT
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_CLKOUT_NOPLL
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_CS
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DATA[0]
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DATA[1]
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DATA[2]
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DATA[3]
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DATA[4]
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DATA[5]
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DATA[6]
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DATA[7]
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_DIR
set_instance_assignment -name IO_STANDARD "1.2 V" -to USB_FAULTN
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_NXT
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_RESETN
set_instance_assignment -name IO_STANDARD "1.8 V" -to USB_STP

set_location_assignment PIN_M8 -to CLK

set_location_assignment PIN_H21 -to NRST

set_location_assignment PIN_C7 -to LED[0]
set_location_assignment PIN_C8 -to LED[1]
set_location_assignment PIN_A6 -to LED[2]
set_location_assignment PIN_B7 -to LED[3]
set_location_assignment PIN_C4 -to LED[4]
set_location_assignment PIN_A5 -to LED[5]
set_location_assignment PIN_B4 -to LED[6]
set_location_assignment PIN_C5 -to LED[7]

set_location_assignment PIN_H11 -to USB_CLKIN
set_location_assignment PIN_H17 -to USB_CLKOUT
set_location_assignment PIN_F16 -to USB_CLKOUT_NOPLL
set_location_assignment PIN_J11 -to USB_CS
set_location_assignment PIN_E12 -to USB_DATA[0]
set_location_assignment PIN_E13 -to USB_DATA[1]
set_location_assignment PIN_H13 -to USB_DATA[2]
set_location_assignment PIN_E14 -to USB_DATA[3]
set_location_assignment PIN_H14 -to USB_DATA[4]
set_location_assignment PIN_D15 -to USB_DATA[5]
set_location_assignment PIN_E15 -to USB_DATA[6]
set_location_assignment PIN_F15 -to USB_DATA[7]
set_location_assignment PIN_J13 -to USB_DIR
set_location_assignment PIN_D8 -to USB_FAULTN
set_location_assignment PIN_H12 -to USB_NXT
set_location_assignment PIN_E16 -to USB_RESETN
set_location_assignment PIN_J12 -to USB_STP


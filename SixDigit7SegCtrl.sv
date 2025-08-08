module SixDigit7SegCtrl (
input logic clk, 
input logic rst,
input logic enable,
input bcdPac_t bcd_packet,
output logic [6:0] HEX0, HEX1,HEX2, HEX3, HEX4, HEX5
);



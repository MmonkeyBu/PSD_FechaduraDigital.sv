module montar_pin (
    input logic clk,
    input logic rst,
    input logic key_valid,
    input logic [3:0] key_code,
    output pinPac_t pin_out
);


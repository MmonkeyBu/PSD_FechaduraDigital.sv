typedef struct packed {
    logic       status;     
    logic [3:0] digit1;     
    logic [3:0] digit2;     
    logic [3:0] digit3;     
    logic [3:0] digit4;     
} pinPac_t;

module update_master (
    input  logic       clk,
    input  logic       rst,
    input  logic       enable, 
    input  pinPac_t    pin_in,         
    output pinPac_t    new_master_pin  
);

  

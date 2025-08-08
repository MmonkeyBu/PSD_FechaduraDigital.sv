module operacional (
    input   logic       clk, 
    input   logic       rst, 
    input   logic       sensor_de_contato, 
    input   logic       botao_interno,
    input   logic       key_valid,
    input   logic [3:0]   key_code,
    output  bcdPac_t    bcd_out,
    output  logic       bcd_enable,
    output  logic       tranca, 
    output  logic       bip,
    output  logic       setup_on,
    input   logic       setup_end,
    output  setupPac_t      data_setup_old,
    input   setupPac_t      data_setup_new
 );


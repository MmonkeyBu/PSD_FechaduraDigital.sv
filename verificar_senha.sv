module verificar_senha (
	input  logic		clk,
	input  logic 		rst,
	input  pinPac_t	    pin_in,         
	input  setupPac_t 	data_setup,     
	output logic 		senha_fail,
	output logic 		senha_padrao,
	output logic 		senha_master,
	output logic		senha_master_update
);

	

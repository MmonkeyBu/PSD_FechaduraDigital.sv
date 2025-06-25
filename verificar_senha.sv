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

	// --- Sinais Internos para Comparação ---

	// Concatena os dígitos do PIN de entrada em um único vetor de 16 bits.
	// Ordem: dígito mais significativo (digit4) para o menos significativo (digit1).
    
	logic [15:0] pin_in_vetor;
	assign pin_in_vetor = {pin_in.digit4, pin_in.digit3, pin_in.digit2, pin_in.digit1};
	
	// Cria vetores de 16 bits para cada senha armazenada no pacote de setup.
	logic [15:0] master_pin_vetor;
	logic [15:0] pin1_vetor;
	logic [15:0] pin2_vetor;
	logic [15:0] pin3_vetor;
	logic [15:0] pin4_vetor;

	assign master_pin_vetor = {data_setup.master_pin.digit4, data_setup.master_pin.digit3, data_setup.master_pin.digit2, data_setup.master_pin.digit1};
	assign pin1_vetor = {data_setup.pin1.digit4, data_setup.pin1.digit3, data_setup.pin1.digit2, data_setup.pin1.digit1};
	assign pin2_vetor = {data_setup.pin2.digit4, data_setup.pin2.digit3, data_setup.pin2.digit2, data_setup.pin2.digit1};
	assign pin3_vetor = {data_setup.pin3.digit4, data_setup.pin3.digit3, data_setup.pin3.digit2, data_setup.pin3.digit1};
	assign pin4_vetor = {data_setup.pin4.digit4, data_setup.pin4.digit3, data_setup.pin4.digit2, data_setup.pin4.digit1};


	// --- Lógica Combinacional (Verificação) ---
	
	logic match_padrao;
	logic match_master;
	logic check_fail;

	// Verifica se o PIN de entrada corresponde a alguma das senhas padrão ATIVAS.
	// Uma senha padrão só é considerada se seu campo 'status' for '1'.
	assign match_padrao = pin_in.status &&
						  ((data_setup.pin1.status && (pin_in_vetor == pin1_vetor)) ||
						   (data_setup.pin2.status && (pin_in_vetor == pin2_vetor)) ||
						   (data_setup.pin3.status && (pin_in_vetor == pin3_vetor)) ||
						   (data_setup.pin4.status && (pin_in_vetor == pin4_vetor)));

	// Verifica se o PIN de entrada corresponde à senha master.
	assign match_master = pin_in.status && (pin_in_vetor == master_pin_vetor);

	// A falha ocorre se a verificação for solicitada e não houver nenhuma correspondência.
	assign check_fail = pin_in.status && !match_padrao && !match_master;

	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			senha_fail          <= 1'b0;
			senha_padrao        <= 1'b0;
			senha_master        <= 1'b0;
			senha_master_update <= 1'b0; 
		end else begin
			senha_fail   <= check_fail;
			senha_padrao <= match_padrao;
			senha_master <= match_master;
			
			if (senha_master) begin
				senha_master_update <= 1'b0;
			end
		end
	end

endmodule

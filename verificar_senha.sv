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

	/*  Desempacota os packets (badum tis)
		* por serem variáveis de 4 bits cada digito, eu tenho uma variável maior de 16 bits
		* que vai corresponder ao conjunto de cada packet de pin
		* ex: pin_in.digit4 = 1, pin_in.digit3 = 2, pin_in.digit2 = 3, pin_in.digit1 = 4
		* pin_in_vetor = 4321, essa variável age como um vetor dos valores.
	*/
	localparam DIGIT_BLANK = 4'hA;
	logic [15:0] pin_in_vetor;
  	logic lock_pin_master;
	logic [15:0] master_pin_vetor;
	logic [15:0] pin1_vetor;
	logic [15:0] pin2_vetor;
	logic [15:0] pin3_vetor;
	logic [15:0] pin4_vetor;
  assign pin_in_vetor = {pin_in.digit4, pin_in.digit3, pin_in.digit2, pin_in.digit1};
	assign master_pin_vetor = {data_setup.master_pin.digit4, data_setup.master_pin.digit3, data_setup.master_pin.digit2, data_setup.master_pin.digit1};
	assign pin1_vetor = {data_setup.pin1.digit4, data_setup.pin1.digit3, data_setup.pin1.digit2, data_setup.pin1.digit1};
	assign pin2_vetor = {data_setup.pin2.digit4, data_setup.pin2.digit3, data_setup.pin2.digit2, data_setup.pin2.digit1};
	assign pin3_vetor = {data_setup.pin3.digit4, data_setup.pin3.digit3, data_setup.pin3.digit2, data_setup.pin3.digit1};
	assign pin4_vetor = {data_setup.pin4.digit4, data_setup.pin4.digit3, data_setup.pin4.digit2, data_setup.pin4.digit1};



	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			senha_fail          <= 1'b0;
			senha_padrao        <= 1'b0;
			senha_master        <= 1'b0;
			senha_master_update <= 1'b1;
          	lock_pin_master     <= 1'b0;
		end else begin
			// Zera todos os valores para garantir que só ocorra um pulso para transição na maquina de estados
			

			/*  É aqui que a verificação ocorre (se pin_in.status for 1 até porque ninguem adivinha)
				* se o usuário não digitar ao menos 4 caracteres := senha_fail <= 1'b1;
				* se o pin de entrada for igual ao master pin := senha_master <= 1;
				* se o pin de entrada for igual a pin* e o pin* está ativo := senha_padrao <= 1;
				* caso fulano digite qualquer coisa exceto as senhas := senha_fail <= 1;
			*/
			if (pin_in.status) begin
				if (pin_in.digit1 == DIGIT_BLANK || pin_in.digit2 == DIGIT_BLANK || pin_in.digit3 == DIGIT_BLANK || pin_in.digit4 == DIGIT_BLANK) begin
                    senha_fail <= 1'b1; 
                end
				else if (pin_in_vetor == master_pin_vetor) begin
                    senha_master <= 1'b1;
					if (!lock_pin_master) begin
						 lock_pin_master <= 1'b1;
					end
				end
				else if ((data_setup.pin1.status && (pin_in_vetor == pin1_vetor)) ||
						   (data_setup.pin2.status && (pin_in_vetor == pin2_vetor)) ||
						   (data_setup.pin3.status && (pin_in_vetor == pin3_vetor)) ||
						   (data_setup.pin4.status && (pin_in_vetor == pin4_vetor))) 
				begin
					senha_padrao <= 1'b1;
				end
				else begin
					senha_fail <= 1'b1;
				end				

			end
			else begin
				senha_master <= 1'b0;
				senha_fail   <= 1'b0;
				senha_padrao <= 1'b0;
                if (lock_pin_master) begin
                  senha_master_update <= 1'b0;
                end else senha_master_update <= senha_master_update;
              
                lock_pin_master <= lock_pin_master;

			end
		end
	end

endmodule

module setup(
    input	logic 		clk, 
    input 	logic 		rst,
    input 	logic 		key_valid,
    input	logic [3:0] 	key_code,
    output 	bcdPac_t 	bcd_out,
    output 	logic 		bcd_enable,
    output 	setupPac_t 	data_setup_new,
    input 	setupPac_t 	data_setup_old,
    input 	logic 		setup_on,
    output	logic 		setup_end
 );

function automatic logic is_valid_digit(input logic [3:0] digit);
    return (digit <= 4'd9); 
endfunction

typedef enum logic [3:0] {
    IDLE,
    RX,
    BIP_ON,
    BIP_TIME,
    AUTO_LOCK,  
    PIN_1,
    PIN_2_ON,
    PIN_2,
    PIN_3_ON,
    PIN_3,
    PIN_4_ON,
    PIN_4,
    TX,
	 DOWN,
	 WAIT,
    UP
} state_t;

state_t current_state, next_state;
pinPac_t pin_sinal_interno;

montar_pin u_montar_pin (
    .clk(clk),
    .rst(rst),
    .key_valid(key_valid),
    .key_code(key_code),
    .pin_out(pin_sinal_interno)
);

// Registradores temporários para a entrada de dados
logic [3:0] bip_time_digit2, bip_time_digit1;       // Para o tempo do bip
logic [3:0] auto_lock_digit2, auto_lock_digit1;
logic [6:0] tempo_local;    // Para o tempo de auto-lock

setupPac_t data_setup;


always_ff @(posedge clk or posedge rst) begin:state_block
    if (rst) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end:state_block


always_ff @(posedge clk or posedge rst) begin:FSM
    if (rst) begin
        data_setup <= '{default:'0};
        bcd_out = '{default:4'hB};
        next_state = IDLE;
        bcd_enable <= 1'b0;
        setup_end <= 1;
    end else begin

    // --- Valores Padrão para cada ciclo ---
    bcd_enable <= 1'b0; 
    
        
    case (current_state)

    IDLE: begin
        if(setup_on) begin
            next_state <= RX;
        end
        else next_state <= next_state;
    end
    RX: begin
        data_setup <= data_setup_old;
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0;
        bcd_out.BCD4 <= 1;
        bcd_out.BCD3 <= 11;
        bcd_out.BCD2 <= 11;
        bcd_out.BCD1 <= 11;
        bcd_out.BCD0 <= data_setup.bip_status;
        next_state <= BIP_ON;
    end
     BIP_ON: begin
            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 0;
            bcd_out.BCD4 <= 1;
            bcd_out.BCD3 <= 11;
            bcd_out.BCD2 <= 11;
            bcd_out.BCD1 <= 11;
            bcd_out.BCD0 <= data_setup.bip_status;

            if (pin_sinal_interno.status && (data_setup.bip_status == 0 || data_setup.bip_status == 1)) begin
					
                bip_time_digit1 <= data_setup.bip_time / 10;
                bip_time_digit2 <= data_setup.bip_time % 10;
                tempo_local <= 0;
                bcd_enable <= 1'b1;
                bcd_out.BCD5 <= 0;
                bcd_out.BCD4 <= 2;
                bcd_out.BCD3 <= 11;
                bcd_out.BCD2 <= 11;
                bcd_out.BCD1 <= bip_time_digit1;
                bcd_out.BCD0 <= bip_time_digit2;
                next_state <= BIP_TIME;
            end
            else if ((pin_sinal_interno.digit1 == 1) || (pin_sinal_interno.digit1 == 0)) begin
                data_setup.bip_status <= pin_sinal_interno.digit1;
            end
            else next_state <= next_state;
    end

    BIP_TIME: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0;
        bcd_out.BCD4 <= 2;
        bcd_out.BCD3 <= 11;
        bcd_out.BCD2 <= 11;
        bcd_out.BCD1 <= bip_time_digit1;
        bcd_out.BCD0 <= bip_time_digit2;


        if(pin_sinal_interno.status && (
            is_valid_digit(bip_time_digit1) &&
            is_valid_digit(bip_time_digit2))) begin
            
            
            tempo_local = (bip_time_digit2 * 10) + bip_time_digit1;
            
        
            if (tempo_local > 60) begin
                data_setup.bip_time <= 7'd60; // Trava no máximo
            end 
            else if (tempo_local < 5) begin
                data_setup.bip_time <= 7'd5;  // Trava no mínimo
            end 
            else begin
                data_setup.bip_time <= tempo_local; // Usa o valor válido
            end
            
            auto_lock_digit1 <= data_setup.tranca_aut_time / 10;
            auto_lock_digit2 <= data_setup.tranca_aut_time % 10;
            tempo_local <= 0;
            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 0;
            bcd_out.BCD4 <= 3;
            bcd_out.BCD3 <= 11;
            bcd_out.BCD2 <= 11;
            bcd_out.BCD1 <= auto_lock_digit1;
            bcd_out.BCD0 <= auto_lock_digit2;
            next_state <= AUTO_LOCK;

        end
            
        else if (pin_sinal_interno.digit1 <= 9 && pin_sinal_interno.digit1 >= 0) begin
            bip_time_digit2 <= pin_sinal_interno.digit1;
            bip_time_digit1 <= pin_sinal_interno.digit2;
        end
        
        else next_state <= next_state;
    end

    AUTO_LOCK: begin    
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0;
        bcd_out.BCD4 <= 3;
        bcd_out.BCD3 <= 11;
        bcd_out.BCD2 <= 11;
        bcd_out.BCD1 <= auto_lock_digit1;
        bcd_out.BCD0 <= auto_lock_digit2;
		  
		   if(pin_sinal_interno.status && (
            is_valid_digit(auto_lock_digit1) &&
            is_valid_digit(auto_lock_digit2))) begin
            
            tempo_local = (auto_lock_digit2 * 10) + auto_lock_digit1;
            
        
            if (tempo_local > 60) begin
                data_setup.tranca_aut_time <= 7'd60; // Trava no máximo
            end 
            else if (tempo_local < 5) begin
                data_setup.tranca_aut_time <= 7'd5;  // Trava no mínimo
            end 
            else begin
                data_setup.tranca_aut_time <= tempo_local; // Usa o valor válido
            end

            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 0; 
            bcd_out.BCD4 <= 4;
            bcd_out.BCD3 <= data_setup.pin1.digit1;
            bcd_out.BCD2 <= data_setup.pin1.digit2;
            bcd_out.BCD1 <= data_setup.pin1.digit3; 
            bcd_out.BCD0 <= data_setup.pin1.digit4;
            
            next_state <= PIN_1;
        end
		  
        else if (is_valid_digit(pin_sinal_interno.digit1)) begin
            auto_lock_digit2 <= pin_sinal_interno.digit1;
            auto_lock_digit1 <= pin_sinal_interno.digit2;
        end


        else next_state <= next_state;
    end
    PIN_1: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 4;
        bcd_out.BCD3 <= data_setup.pin1.digit1;
        bcd_out.BCD2 <= data_setup.pin1.digit2;
        bcd_out.BCD1 <= data_setup.pin1.digit3; 
        bcd_out.BCD0 <= data_setup.pin1.digit4;
		  
		  if(pin_sinal_interno.status && (
            is_valid_digit(data_setup.pin1.digit1) &&
            is_valid_digit(data_setup.pin1.digit2) &&
            is_valid_digit(data_setup.pin1.digit3) &&
            is_valid_digit(data_setup.pin1.digit4))) begin
            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 0; 
            bcd_out.BCD4 <= 5;
            bcd_out.BCD3 <= 11;
            bcd_out.BCD2 <= 11;
            bcd_out.BCD1 <= 11; 
            bcd_out.BCD0 <= data_setup.pin2.status;
            next_state <= PIN_2_ON;
        end
		  
        else if (is_valid_digit(pin_sinal_interno.digit1)) begin
            data_setup.pin1.digit1 <= pin_sinal_interno.digit4;
            data_setup.pin1.digit2 <= pin_sinal_interno.digit3;
            data_setup.pin1.digit3 <= pin_sinal_interno.digit2;
            data_setup.pin1.digit4 <= pin_sinal_interno.digit1;
        end

        else next_state <= next_state;
    end
    PIN_2_ON: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 5;
        bcd_out.BCD3 <= 11;
        bcd_out.BCD2 <= 11;
        bcd_out.BCD1 <= 11; 
        bcd_out.BCD0 <= data_setup.pin2.status; 
		  
		  if(pin_sinal_interno.status && (data_setup.pin2.status == 0 || data_setup.pin2.status == 1)) begin
            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 0; 
            bcd_out.BCD4 <= 6;
            bcd_out.BCD3 <= data_setup.pin2.digit1;
            bcd_out.BCD2 <= data_setup.pin2.digit2;
            bcd_out.BCD1 <= data_setup.pin2.digit3; 
            bcd_out.BCD0 <= data_setup.pin2.digit4;
            next_state <= PIN_2;
        end
        
        else if (pin_sinal_interno.digit1 == 1 || pin_sinal_interno.digit1 == 0) begin
            data_setup.pin2.status <= pin_sinal_interno.digit1;
        end

        else next_state <= next_state;
    
    end
    PIN_2: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 6;
        bcd_out.BCD3 <= data_setup.pin2.digit1;
        bcd_out.BCD2 <= data_setup.pin2.digit2;
        bcd_out.BCD1 <= data_setup.pin2.digit3; 
        bcd_out.BCD0 <= data_setup.pin2.digit4;
		  
		if(pin_sinal_interno.status && (
            is_valid_digit(data_setup.pin2.digit1) &&
            is_valid_digit(data_setup.pin2.digit2) &&
            is_valid_digit(data_setup.pin2.digit3) &&
            is_valid_digit(data_setup.pin2.digit4))) begin
            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 0; 
            bcd_out.BCD4 <= 7;
            bcd_out.BCD3 <= 11;
            bcd_out.BCD2 <= 11;
            bcd_out.BCD1 <= 11; 
            bcd_out.BCD0 <= data_setup.pin3.status;
            next_state <= PIN_3_ON;
        end
		  
        
        else if (pin_sinal_interno.digit1 <= 9 && pin_sinal_interno.digit1 >= 0 ) begin
            data_setup.pin2.digit1 <= pin_sinal_interno.digit4;
            data_setup.pin2.digit2 <= pin_sinal_interno.digit3;
            data_setup.pin2.digit3 <= pin_sinal_interno.digit2;
            data_setup.pin2.digit4 <= pin_sinal_interno.digit1;
        end

        else next_state <= next_state;
    end
    PIN_3_ON: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 7;
        bcd_out.BCD3 <= 11;
        bcd_out.BCD2 <= 11;
        bcd_out.BCD1 <= 11; 
        bcd_out.BCD0 <= data_setup.pin3.status;
        
        if(pin_sinal_interno.status && (data_setup.pin3.status == 0 || data_setup.pin3.status == 1)) begin
            next_state <= PIN_3;
            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 0; 
            bcd_out.BCD4 <= 8;
            bcd_out.BCD3 <= data_setup.pin3.digit1;
            bcd_out.BCD2 <= data_setup.pin3.digit2;
            bcd_out.BCD1 <= data_setup.pin3.digit3; 
            bcd_out.BCD0 <= data_setup.pin3.digit4;
        end
		  
        else if (pin_sinal_interno.digit1 == 1 || pin_sinal_interno.digit1 == 0) begin
            data_setup.pin3.status <= pin_sinal_interno.digit1;
        end

        else next_state <= next_state;
    
    end
    PIN_3: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 8;
        bcd_out.BCD3 <= data_setup.pin3.digit1;
        bcd_out.BCD2 <= data_setup.pin3.digit2;
        bcd_out.BCD1 <= data_setup.pin3.digit3; 
        bcd_out.BCD0 <= data_setup.pin3.digit4;
		  
		  if(pin_sinal_interno.status && (
            is_valid_digit(data_setup.pin3.digit1) &&
            is_valid_digit(data_setup.pin3.digit2) &&
            is_valid_digit(data_setup.pin3.digit3) &&
            is_valid_digit(data_setup.pin3.digit4))) begin
                bcd_enable <= 1'b1;
                bcd_out.BCD5 <= 0; 
                bcd_out.BCD4 <= 9;
                bcd_out.BCD3 <= 11;
                bcd_out.BCD2 <= 11;
                bcd_out.BCD1 <= 11; 
                bcd_out.BCD0 <= data_setup.pin4.status;
                next_state <= PIN_4_ON;
			end
				 
        else if (pin_sinal_interno.digit1 <= 9 && pin_sinal_interno.digit1 >= 0 ) begin
				 data_setup.pin3.digit1 <= pin_sinal_interno.digit4;
				 data_setup.pin3.digit2 <= pin_sinal_interno.digit3;
				 data_setup.pin3.digit3 <= pin_sinal_interno.digit2;
				 data_setup.pin3.digit4 <= pin_sinal_interno.digit1;
			end

        else next_state <= next_state;
    end
    PIN_4_ON: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 9;
        bcd_out.BCD3 <= 11;
        bcd_out.BCD2 <= 11;
        bcd_out.BCD1 <= 11; 
        bcd_out.BCD0 <= data_setup.pin4.status;
        if(pin_sinal_interno.status && (data_setup.pin4.status == 0 || data_setup.pin4.status == 1)) begin
            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 1; 
            bcd_out.BCD4 <= 0;
            bcd_out.BCD3 <= data_setup.pin4.digit1;
            bcd_out.BCD2 <= data_setup.pin4.digit2;
            bcd_out.BCD1 <= data_setup.pin4.digit3; 
            bcd_out.BCD0 <= data_setup.pin4.digit4;
            next_state <= PIN_4;
        end
			
			else if (pin_sinal_interno.digit1 == 1 || pin_sinal_interno.digit1 == 0) begin
				 data_setup.pin4.status <= pin_sinal_interno.digit1;
			end
        else next_state <= next_state;
    
    end
    PIN_4: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 1; 
        bcd_out.BCD4 <= 0;
        bcd_out.BCD3 <= data_setup.pin4.digit1;
        bcd_out.BCD2 <= data_setup.pin4.digit2;
        bcd_out.BCD1 <= data_setup.pin4.digit3; 
        bcd_out.BCD0 <= data_setup.pin4.digit4;
		  
		  if(pin_sinal_interno.status && (
            is_valid_digit(data_setup.pin4.digit1) &&
            is_valid_digit(data_setup.pin4.digit2) &&
            is_valid_digit(data_setup.pin4.digit3) &&
            is_valid_digit(data_setup.pin4.digit4))) begin
				 next_state <= TX;
			end
		  
			
			else if (pin_sinal_interno.digit1 <= 9 && pin_sinal_interno.digit1 >= 0 ) begin
				 data_setup.pin4.digit1 <= pin_sinal_interno.digit4;
				 data_setup.pin4.digit2 <= pin_sinal_interno.digit3;
				 data_setup.pin4.digit3 <= pin_sinal_interno.digit2;
				 data_setup.pin4.digit4 <= pin_sinal_interno.digit1;
			end
	  
        else next_state <= next_state;
    end
    TX: begin
        data_setup_new <= data_setup;
        next_state <= DOWN;
    end
	 DOWN: begin
		setup_end <= 0;
		next_state <= WAIT;
	 end
	 WAIT: begin
		if (!setup_on) begin
			next_state <= UP;
		end
		else next_state <= next_state;
	 end
    UP: begin
        setup_end <= 1;
        next_state <= IDLE;
    end
    default: begin
        next_state <= IDLE;
    end

    endcase
    end
end:FSM

endmodule

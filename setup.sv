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
    UP
} state_t;

state_t current_state, next_state;

localparam KEY_SEND = 4'hF; 
// Registradores temporários para a entrada de dados
logic [3:0] bip_time_digit2, bip_time_digit1;       // Para o tempo do bip
logic [3:0] auto_lock_digit2, auto_lock_digit1;
logic [6:0] tempo_local;    // Para o tempo de auto-lock

// --- Lógica de Detecção de Borda ---
logic tecla_valid_d1;
logic tecla_valid_posedge;
setupPac_t data_setup;

always_ff @(posedge clk or posedge rst) begin:DetectorDeBorda
        if (rst) begin
            tecla_valid_d1 <= 1'b0;
        end else begin
            tecla_valid_d1 <= key_valid;
        end
end:DetectorDeBorda

assign tecla_valid_posedge = key_valid && !tecla_valid_d1;

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
        bcd_out = '{default:'0};
        next_state = IDLE;
        bcd_enable <= 1'b0;
        setup_end <= 0;
    end else begin

    // --- Valores Padrão para cada ciclo ---
    next_state <= current_state;
    bcd_enable <= 1'b0; 
    bcd_out    <= '{default:'0};
    setup_end <= 0;
        
    case (current_state)

    IDLE: begin
        if(setup_on) begin
            next_state <= RX;
        end
        else next_state <= next_state;
    end
    RX: begin
        data_setup <= data_setup_old;
        next_state <= BIP_ON;
    end
     BIP_ON: begin
            bcd_enable <= 1'b1;
            bcd_out.BCD5 <= 0;
            bcd_out.BCD4 <= 1;
            bcd_out.BCD0 <= data_setup.bip_status;

        if (tecla_valid_posedge) begin
            if (key_code == 1 || key_code == 0) begin
                data_setup.bip_status <= key_code;
            end
            else if (key_code == KEY_SEND) begin
            
                bip_time_digit1 <= 4'd0;
                bip_time_digit2 <= 4'd0;
                tempo_local <= 0;
                next_state <= BIP_TIME;
            end
        end
        else next_state <= next_state;
    end

    BIP_TIME: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0;
        bcd_out.BCD4 <= 2;
        bcd_out.BCD1 <= bip_time_digit2;
        bcd_out.BCD0 <= bip_time_digit1;

        if (tecla_valid_posedge) begin
            if (key_code <= 9 && key_code >= 0) begin
                bip_time_digit2 <= bip_time_digit1;
                bip_time_digit1 <= key_code;
            end
            else if (key_code == KEY_SEND) begin
                
               
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
                
                // Prepara para o próximo estado
                auto_lock_digit1 <= 4'd0;
                auto_lock_digit2 <= 4'd0;
                tempo_local <= 0;
                next_state <= AUTO_LOCK;

            end
        end 
        else next_state <= next_state;
    end

    AUTO_LOCK: begin    
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0;
        bcd_out.BCD4 <= 3;
        bcd_out.BCD1 <= auto_lock_digit2;
        bcd_out.BCD0 <= auto_lock_digit1;
        if (tecla_valid_posedge) begin

            if (key_code <= 9 && key_code >= 0) begin
                auto_lock_digit2 <= auto_lock_digit1;
                auto_lock_digit1 <= key_code;
            end

            else if (key_code == KEY_SEND) begin
            
                
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
                
                next_state <= PIN_1;
            end
        end 
        else next_state <= next_state;
    end
    PIN_1: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 4;
        bcd_out.BCD3 <= data_setup.pin1.digit4;
        bcd_out.BCD2 <= data_setup.pin1.digit3;
        bcd_out.BCD1 <= data_setup.pin1.digit2; 
        bcd_out.BCD0 <= data_setup.pin1.digit1;
        if(tecla_valid_posedge) begin
            if (key_code <= 9 && key_code >= 0 ) begin
                data_setup.pin1.digit1 <= data_setup.pin1.digit2;
                data_setup.pin1.digit2 <= data_setup.pin1.digit3;
                data_setup.pin1.digit3 <= data_setup.pin1.digit4;
                data_setup.pin1.digit4 <= key_code;
            end
            else if(key_code == KEY_SEND) begin
                next_state <= PIN_2_ON;
            end
        end
        else next_state <= next_state;
    end
    PIN_2_ON: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 5; 
        bcd_out.BCD0 <= data_setup.pin2.status; 
        if(tecla_valid_posedge) begin
            if (key_code == 1 || key_code == 0) begin
                data_setup.pin2.status <= key_code;
            end
            else if(key_code == KEY_SEND) begin
                next_state <= PIN_2;
            end
        end
        else next_state <= next_state;
    
    end
    PIN_2: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 6;
        bcd_out.BCD3 <= data_setup.pin2.digit4;
        bcd_out.BCD2 <= data_setup.pin2.digit3;
        bcd_out.BCD1 <= data_setup.pin2.digit2; 
        bcd_out.BCD0 <= data_setup.pin2.digit1;
        if(tecla_valid_posedge) begin
            if (key_code <= 9 && key_code >= 0 ) begin
                data_setup.pin2.digit1 <= data_setup.pin2.digit2;
                data_setup.pin2.digit2 <= data_setup.pin2.digit3;
                data_setup.pin2.digit3 <= data_setup.pin2.digit4;
                data_setup.pin2.digit4 <= key_code;
            end
            else if(key_code == KEY_SEND) begin
                next_state <= PIN_3_ON;
            end
        end
        else next_state <= next_state;
    end
    PIN_3_ON: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 7; 
        bcd_out.BCD0 <= data_setup.pin3.status;
        if(tecla_valid_posedge) begin
            if (key_code == 1 || key_code == 0) begin
                data_setup.pin3.status <= key_code;
            end
            else if(key_code == KEY_SEND) begin
                next_state <= PIN_3;
            end
        end
        else next_state <= next_state;
    
    end
    PIN_3: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 8;
        bcd_out.BCD3 <= data_setup.pin3.digit4;
        bcd_out.BCD2 <= data_setup.pin3.digit3;
        bcd_out.BCD1 <= data_setup.pin3.digit2; 
        bcd_out.BCD0 <= data_setup.pin3.digit1;
        if(tecla_valid_posedge) begin
            if (key_code <= 9 && key_code >= 0 ) begin
                data_setup.pin3.digit1 <= data_setup.pin3.digit2;
                data_setup.pin3.digit2 <= data_setup.pin3.digit3;
                data_setup.pin3.digit3 <= data_setup.pin3.digit4;
                data_setup.pin3.digit4 <= key_code;
            end
            else if(key_code == KEY_SEND) begin
                next_state <= PIN_4_ON;
            end
        end
        else next_state <= next_state;
    end
    PIN_4_ON: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 0; 
        bcd_out.BCD4 <= 9; 
        bcd_out.BCD0 <= data_setup.pin4.status;
        if(tecla_valid_posedge) begin
            if (key_code == 1 || key_code == 0) begin
                data_setup.pin4.status <= key_code;
            end
            else if(key_code == KEY_SEND) begin
                next_state <= PIN_4;
            end
        end
        else next_state <= next_state;
    
    end
    PIN_4: begin
        bcd_enable <= 1'b1;
        bcd_out.BCD5 <= 1; 
        bcd_out.BCD4 <= 0;
        bcd_out.BCD3 <= data_setup.pin4.digit4;
        bcd_out.BCD2 <= data_setup.pin4.digit3;
        bcd_out.BCD1 <= data_setup.pin4.digit2; 
        bcd_out.BCD0 <= data_setup.pin4.digit1;
        if(tecla_valid_posedge) begin
            if (key_code <= 9 && key_code >= 0 ) begin
                data_setup.pin4.digit1 <= data_setup.pin4.digit2;
                data_setup.pin4.digit2 <= data_setup.pin4.digit3;
                data_setup.pin4.digit3 <= data_setup.pin4.digit4;
                data_setup.pin4.digit4 <= key_code;
            end
            else if(key_code == KEY_SEND) begin
                next_state <= TX;
            end
        end
        else next_state <= next_state;
    end
    TX: begin
        data_setup_new <= data_setup;
        next_state <= UP;
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
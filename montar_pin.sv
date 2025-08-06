module montar_pin (
    input logic clk,
    input logic rst,
    input logic key_valid,
    input logic [3:0] key_code,
    output pinPac_t pin_out
);


    function automatic logic is_valid_digit(input logic [3:0] digit);
        return (digit <= 4'd9); 
    endfunction
    // --- Constantes ---
    localparam KEY_SEND = 4'hF; 
    localparam DIGIT_BLANK = 4'hE; 

    // Flag auxiliar para gerenciar a limpeza do PIN no ciclo seguinte ao envio/limissão.
    logic pending_clear;

    // --- Lógica de Detecção de Borda ---
    logic tecla_valid_d1;
    logic tecla_valid_posedge;

    always_ff @(posedge clk or posedge rst) begin:DetectorDeBorda
        if (rst) begin
            tecla_valid_d1 <= 1'b0;
        end else begin
            tecla_valid_d1 <= key_valid;
        end
    end:DetectorDeBorda

    assign tecla_valid_posedge = key_valid && !tecla_valid_d1;

    // --- Lógica Principal de Montagem e Estado do PIN ---
    always_ff @(posedge clk or posedge rst) begin:RegDeslocamento
        if (rst) begin
            pin_out.status <= 1'b0;
            pin_out.digit1 <= DIGIT_BLANK;
            pin_out.digit2 <= DIGIT_BLANK;
            pin_out.digit3 <= DIGIT_BLANK;
            pin_out.digit4 <= DIGIT_BLANK;
            pending_clear <= 1'b0; 
        end else begin

            /*--- Fase 1: Limpeza / Reset de Pulso ---
                * Garante que o modulo só envie pin_out.status por um pulso
             */ 
            if (pending_clear) begin
                pin_out.status <= 1'b0; 
                pin_out.digit1 <= DIGIT_BLANK;
                pin_out.digit2 <= DIGIT_BLANK;
                pin_out.digit3 <= DIGIT_BLANK;
                pin_out.digit4 <= DIGIT_BLANK;
                pending_clear <= 1'b0; 
            end else begin
                pin_out.status <= 1'b0;
            end


            // --- Fase 2: Processamento do Pressionamento de Tecla ---

            if (tecla_valid_posedge) begin
                if (key_code == KEY_SEND) begin 

                    pin_out.status <= 1'b1;
                    pending_clear <= 1'b1;

                end
                // Limpa a tela, comportamento simples e direto (se for necessario, e o professor quiser, posso limpar um por vez também)
                else if (key_code == 4'hE) begin 

                    pin_out.digit1 <= DIGIT_BLANK;
                    pin_out.digit2 <= DIGIT_BLANK;
                    pin_out.digit3 <= DIGIT_BLANK;
                    pin_out.digit4 <= DIGIT_BLANK;
                    pin_out.status <= 1'b0;
                    pending_clear <= 1'b0; 

                end
                else begin // É um dígito normal (0-9, A-D)
                    if(is_valid_digit(key_code))
                        pin_out.digit4 <= pin_out.digit3;
                        pin_out.digit3 <= pin_out.digit2;
                        pin_out.digit2 <= pin_out.digit1;
                        pin_out.digit1 <= key_code;
                        pin_out.status <= 1'b0;
                        pending_clear <= 1'b0;

                end
            end
        end
    end:RegDeslocamento
endmodule

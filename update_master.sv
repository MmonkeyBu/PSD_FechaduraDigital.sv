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

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            new_master_pin.status <= 1'b0;
            new_master_pin.digit1 <= 4'hF;  // Valor inválido (15)
            new_master_pin.digit2 <= 4'hF;  // Valor inválido (15) 
            new_master_pin.digit3 <= 4'hF;  // Valor inválido (15)
            new_master_pin.digit4 <= 4'hF;  // Valor inválido (15)
        end else begin
            if (enable) begin 
                // O campo 'pin_in.status' se torna '1' quando o usuário pressiona '*'
                if (pin_in.status) begin
                    // Verifica se os dígitos recebidos são válidos (0-9)
                    if ((pin_in.digit1 <= 4'd9) && (pin_in.digit2 <= 4'd9) && 
                        (pin_in.digit3 <= 4'd9) && (pin_in.digit4 <= 4'd9)) begin
                        // PIN válido: atualiza o master PIN
                        new_master_pin.status <= 1'b1;
                        new_master_pin.digit1 <= pin_in.digit1;
                        new_master_pin.digit2 <= pin_in.digit2;
                        new_master_pin.digit3 <= pin_in.digit3;
                        new_master_pin.digit4 <= pin_in.digit4;
                    end else begin
                        // PIN inválido: mantém status em 0
                        new_master_pin.status <= 1'b0;
                    end
                end else begin
                    // Se não há confirmação, mantém status em 0 para próxima confirmação
                    new_master_pin.status <= 1'b0;
                end
            end
        end
    end

endmodule

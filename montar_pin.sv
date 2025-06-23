module montar_pin (
    input logic clk,
    input logic rst,
    input logic key_valid,
    input logic [3:0] key_code,
    output pinPac_t pin_out
);
    // --- Constantes ---

    localparam KEY_SEND = 4'hE; 
    localparam INVALID_PIN = 16'hFFFF;

    // --- Sinais Internos ---
    // Buffer interno para montar a senha de forma segura, sem afetar a saída
    logic [15:0] pin_buffer; 

    // --- Lógica de Detecção de Borda ---
    logic tecla_valid_d1;
    logic tecla_valid_posedge;

    always_ff @(posedge clk or posedge rst) begin:DetectorDeBorda
        if (rst) tecla_valid_d1 <= 1'b0;
        else     tecla_valid_d1 <= key_valid;
    end:DetectorDeBorda

    
    assign tecla_valid_posedge = key_valid && !tecla_valid_d1;

    // --- Lógica Principal de Estado do PIN ---
    always_ff @(posedge clk or posedge rst) begin:RegDeslocamento
        if (rst) begin
            pin_out <= '{default: '0}; // Reseta a saída
            pin_buffer <= 16'h0000;    // Reseta o buffer interno
        end else begin

            if (tecla_valid_posedge) begin

                if (key_code == KEY_SEND) begin: envia_pin

                    pin_out.status <= 1'b1;
                    {pin_out.digit4, pin_out.digit3, pin_out.digit2, pin_out.digit1} <= pin_buffer;

                end:envia_pin else begin: shifta_pin

                    pin_out.status <= 1'b0; 
                    {pin_out.digit4, pin_out.digit3, pin_out.digit2, pin_out.digit1} <= INVALID_PIN; 
                    

                    pin_buffer <= {pin_buffer[11:0], key_code};

                end:shifta_pin
            end
        end
    end:RegDeslocamento
endmodule

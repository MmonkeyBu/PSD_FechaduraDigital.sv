
module resetHold5s #(
    parameter TIME_TO_RST = 5
) (
    input  logic clk,         // Clock de entrada (ex: 1kHz)
    input  logic reset_in,    // Sinal de reset de entrada (ativo alto)
    output logic reset_out    // Sinal de reset de saída, estendido por TIME_TO_RST segundos
);

    // Calcula o valor máximo que o contador deve atingir.
    // Ex: 5 segundos * 1000 Hz = 5000 ciclos.
	localparam CLK_FREQ_HZ = 1000;
    localparam COUNT_MAX = TIME_TO_RST * CLK_FREQ_HZ;

    // Declaração do contador.
    // $clog2 calcula o número de bits necessários para armazenar COUNT_MAX.
    // Para 5000, $clog2(5000) = 13. Portanto, o contador terá 13 bits.
    logic [$clog2(COUNT_MAX)-1:0] counter_reg;

    logic reset_out_reg;

    
    assign reset_out = reset_out_reg;

    always_ff @(posedge clk) begin
        
        if (reset_in) begin
            reset_out_reg <= 1'b0; 
            counter_reg   <= 0;   
        
        end else if (reset_out_reg) begin
            
            if (counter_reg < COUNT_MAX - 1) begin
                counter_reg <= counter_reg + 1; 
            end else begin
                reset_out_reg <= 1'b1; 
            end
        end
    end

endmodule

module resetHold5s #(
    parameter TIME_TO_RST = 5
) (
    input  logic clk,         // Clock de entrada (ex: 1kHz)
    input  logic reset_in,    // Sinal de reset de entrada (ativo alto)
    output logic reset_out    // Sinal de reset de saída, estendido por TIME_TO_RST segundos
);

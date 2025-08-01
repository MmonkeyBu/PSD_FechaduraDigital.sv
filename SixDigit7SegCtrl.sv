module SixDigit7SegCtrl (
input logic clk, 
input logic rst,
input logic enable,
input bcdPac_t bcd_packet,
output logic [6:0] HEX0, HEX1,HEX2, HEX3, HEX4, HEX5
);

    logic tecla_valid_d1; 
    logic tecla_valid_posedge;

    // Função para converter BCD para 7 segmentos
    function logic [6:0] bcd_to_7seg(input logic [4:0] bcd);
        case (bcd)
            4'h0: bcd_to_7seg = 7'b0111111;
            4'h1: bcd_to_7seg = 7'b0000110;
            4'h2: bcd_to_7seg = 7'b1011011;
            4'h3: bcd_to_7seg = 7'b1001111;
            4'h4: bcd_to_7seg = 7'b1100110;
            4'h5: bcd_to_7seg = 7'b1101101;
            4'h6: bcd_to_7seg = 7'b1111101;
            4'h7: bcd_to_7seg = 7'b0000111;
            4'h8: bcd_to_7seg = 7'b1111111;
            4'h9: bcd_to_7seg = 7'b1100111;
            4'hA: bcd_to_7seg = 7'b1110111; 
            4'hB: bcd_to_7seg = 7'b1111100; 
            4'hC: bcd_to_7seg = 7'b0111001; 
            4'hD: bcd_to_7seg = 7'b1011110;  
            4'hF: bcd_to_7seg = 7'b1000000; 

            default: bcd_to_7seg = 7'b1111111; 
        endcase
    endfunction

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tecla_valid_d1 <= 1'b0; 
        end else begin

            tecla_valid_d1 <= enable;

            if (tecla_valid_posedge) begin 
                
                HEX0 = ~bcd_to_7seg(bcd_packet.BCD0);
                HEX1 = ~bcd_to_7seg(bcd_packet.BCD1);
                HEX2 = ~bcd_to_7seg(bcd_packet.BCD2);
                HEX3 = ~bcd_to_7seg(bcd_packet.BCD3);
                HEX4 = ~bcd_to_7seg(bcd_packet.BCD4);
                HEX5 = ~bcd_to_7seg(bcd_packet.BCD5);

            end
        end
    end

    assign tecla_valid_posedge = enable && !tecla_valid_d1;

endmodule

module matrixKeyDecoder (
    input clk, reset,
    input 	logic [3:0] col_matrix,
    output 	logic [3:0] lin_matrix,
    output 	logic [3:0] tecla_value,
    output	logic tecla_valid
);


parameter DEBOUNCE_P = 100;
parameter logic [3:0] HIGH = 4'b1111;

typedef enum logic [2:0] {
    INICIAL,
    DB,
    PRESS_STATE,
    RELEASE_STATE
} state_t;

typedef enum logic [3:0] {
    W = 4'b0111,
    X = 4'b1011,
    Y = 4'b1101,
    Z = 4'b1110
} IO_t;

typedef enum logic [3:0] {
    um        = 4'h1,
    dois      = 4'h2,
    tres      = 4'h3,
    quatro    = 4'h4,
    cinco     = 4'h5,
    seis      = 4'h6,
    sete      = 4'h7,
    oito      = 4'h8,
    nove      = 4'h9,
    zero      = 4'h0,
    asterisco = 4'hF,
    hashtag   = 4'hE,
    A         = 4'hA,
    B         = 4'hB,
    C         = 4'hC,
    D         = 4'hD  
} BCD_t;

   

state_t current_state, next_state;
logic [8:0] Tp;
int index;
localparam logic [3:0] array [3:0] = '{W, X, Y, Z};


always_ff @(posedge clk or posedge reset) begin:state_block
    if (reset) begin
        current_state <= INICIAL;
    end else begin
        current_state <= next_state;
    end
end:state_block

always_ff @(posedge clk or posedge reset) begin:counter
    if (reset) begin
        Tp <= 0;
    end else begin
        Tp <= Tp;
    case (current_state)
    DB: begin
        Tp <= Tp + 1;
    end
    default: begin
        Tp <= 0;
    end
    endcase
    end
end:counter

always_ff @(posedge clk or posedge reset) begin:FSM
    if (reset) begin
        next_state <= INICIAL;
        index <= 0;
        lin_matrix <= array[0];
                    tecla_valid <= 0;
    end else case (current_state)

    INICIAL: begin
        
        index <= index + 1;
        lin_matrix <= array[index];

        if  (col_matrix != HIGH) begin
            next_state <= DB;
        end
        else if (index > 3) begin
            index <= 0;
        end
        else begin
            next_state <= next_state;
        end
    end

    DB: begin
        if (Tp + 3 == DEBOUNCE_P) begin
            if  (col_matrix != HIGH) begin
                next_state <= PRESS_STATE;
            end else begin
                next_state <= INICIAL;
            end
        end else begin
            next_state <= DB;
        end
    end

    PRESS_STATE: begin

        case (lin_matrix)
        W: begin
            case (col_matrix)
            W: begin
                tecla_value <= um;
                tecla_valid <= 1;
                next_state <= RELEASE_STATE;
            end
            X: begin
                tecla_value <= dois;
                tecla_valid <= 1;
                next_state <= RELEASE_STATE;
            end
            Y: begin
                tecla_value <= tres;
                tecla_valid <= 1;
                next_state <= RELEASE_STATE;
            end
            Z: begin
                tecla_value <= A;
                tecla_valid <= 1;
                next_state <= RELEASE_STATE;
            end
            default: begin
                tecla_value <= 0;
                tecla_valid <= 0;
                next_state <= INICIAL;
            end
        endcase
        end
        X: begin
            case (col_matrix)
            W: begin
                tecla_value <= quatro;
                tecla_valid <= 1;
                next_state <= RELEASE_STATE;
            end
            X: begin
                tecla_value <= cinco;
                tecla_valid <= 1;
                next_state <= RELEASE_STATE;
            end
            Y: begin
                tecla_value <= seis;
                tecla_valid <= 1;
                next_state <= RELEASE_STATE;
            end
            Z: begin
                tecla_value <= B;
                tecla_valid <= 1;
                next_state <= RELEASE_STATE;
            end
            default: begin
                tecla_value <= 0;
                tecla_valid <= 0;
                next_state <= INICIAL;
            end
            endcase
        end

        Y: begin
            case (col_matrix)
                W: begin
                    tecla_value <= sete;
                    tecla_valid <= 1;
                    next_state <= RELEASE_STATE;
                end
                X: begin
                    tecla_value <= oito;
                    tecla_valid <= 1;
                    next_state <= RELEASE_STATE;
                end
                Y: begin
                    tecla_value <= nove;
                    tecla_valid <= 1;
                    next_state <= RELEASE_STATE;
                end
                Z: begin
                    tecla_value <= C;
                    tecla_valid <= 1;
                    next_state <= RELEASE_STATE;
                end
                default: begin
                    tecla_value <= 0;
                    tecla_valid <= 0;
                    next_state <= INICIAL;
                end
            endcase
    end

    Z: begin
        case (col_matrix)
        W: begin
            tecla_value <= asterisco;
            tecla_valid <= 1;
            next_state <= RELEASE_STATE;
        end
        X: begin
            tecla_value <= zero;
            tecla_valid <= 1;
            next_state <= RELEASE_STATE;
        end
        Y: begin
            tecla_value <= hashtag;
            tecla_valid <= 1;
            next_state <= RELEASE_STATE;
        end
        Z: begin
            tecla_value <= D;
            tecla_valid <= 1;
            next_state <= RELEASE_STATE;
        end
        default: begin
            tecla_value <= 0;
            tecla_valid <= 0;
            next_state <= INICIAL;
        end
        endcase
    end
    default: begin
        tecla_value <= 0;
        tecla_valid <= 0;
        next_state <= INICIAL;
    end
    endcase

    end

    RELEASE_STATE: begin
        tecla_valid <= 0;
        if  (col_matrix == HIGH) begin
                next_state <= INICIAL;
        end
    end

    default: begin
        next_state <= PRESS_STATE;
    end

    endcase
end:FSM

endmodule



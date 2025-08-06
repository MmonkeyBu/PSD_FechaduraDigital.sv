module operacional (
    input   logic       clk, 
    input   logic       rst, 
    input   logic       sensor_de_contato, 
    input   logic       botao_interno,
    input   logic       key_valid,
    input   logic [3:0]   key_code,
    output  bcdPac_t    bcd_out,
    output  logic       bcd_enable,
    output  logic       tranca, 
    output  logic       bip,
    output  logic       setup_on,
    input   logic       setup_end,
    output  setupPac_t      data_setup_old,
    input   setupPac_t      data_setup_new
 );

    // --- Parâmetros e Sinais Internos ---
    localparam CLK_FREQ_HZ = 1000; // Frequência para cálculo de tempo
    localparam MAX_FALHAS = 3;     // Máximo de tentativas de senha
    localparam TEMPO_ESPERA_SEGUNDOS = 10; // Tempo de bloqueio em segundos

    pinPac_t pin_sinal_interno;
    pinPac_t novo_master_pin_sinal;
    setupPac_t   data_setup_reg; // Registrador interno para a configuração

    logic       senha_fail,
                senha_padrao, 
                senha_master, 
                senha_master_update, 
                enable,
                update_master,
                update_master_flag;
;
    
    // Contadores
    logic [6:0] contador_falhas;
    logic [23:0] contagem_espera; // Contador para o tempo de bloqueio
    logic [23:0] contagem_travamento;
    logic [23:0] contagem_bip;

    // --- Instanciação dos Submódulos ---
    // (Assumindo que estes módulos existem no projeto)
    montar_pin u_montar_pin (
        .clk(clk),
        .rst(rst),
        .key_valid(key_valid),
        .key_code(key_code),
        .pin_out(pin_sinal_interno)
    );

    verificar_senha u_verificar_senha (
        .clk(clk),
        .rst(rst),
        .pin_in(pin_sinal_interno),
        .data_setup(data_setup_reg), // Usa o registrador interno
        .senha_fail(senha_fail),
        .senha_padrao(senha_padrao),
        .senha_master(senha_master),
        .senha_master_update(senha_master_update)
    );

    update_master u_update_master (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .pin_in(pin_sinal_interno),
        .new_master_pin(novo_master_pin_sinal)
    );

    // --- Definição da Máquina de Estados ---
    typedef enum logic [3:0] {
        RESET,
        MONTAR_PIN,
        ESPERA,           // Estado de bloqueio por erro de senha
        VERIFICAR_SENHA,  // Estado transiente para checar a senha
        UPDATE_MASTER,    // Estado para atualizar a senha master
        SETUP,            // Estado de espera pelo fim do modo de configuração
        TRAVA_OFF,        // Estado destravado, decide o que fazer a seguir
        PORTA_FECHADA,    // Destravado com porta fechada (contando para travar)
        PORTA_ABERTA,     // Destravado com porta aberta (contando para bipar)
        TRAVA_ON          // Estado principal, travado e aguardando senha
    } state_t;

    state_t current_state, next_state;
    
    // FIX: Ligar a saída 'data_setup_old' ao registrador interno
    assign data_setup_old = data_setup_reg;
    assign update_master = (!senha_master_update && senha_master && !update_master_flag);
	 
	logic botao_interno_d1, botao_interno_d2;
	logic botao_pressionado_pulso;

	always_ff @(posedge clk or posedge rst) begin
      if (rst) begin
          botao_interno_d1 <= 0;
          botao_interno_d2 <= 0;
      end else begin
          botao_interno_d1 <= botao_interno;
          botao_interno_d2 <= botao_interno_d1;
      end
	end

// Gera um pulso de 1 ciclo de clock quando o botão é pressionado
	assign botao_pressionado_pulso = botao_interno_d1 && !botao_interno_d2;

    // --- Bloco de Transição de Estado ---
    always_ff @(posedge clk or posedge rst) begin: state_transition_block
        if (rst) begin
            current_state <= RESET;
        end else begin
            current_state <= next_state;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            update_master_flag <= 1'b0;
        end else if (update_master) begin
            update_master_flag <= 1'b1;
        end
    end

    // --- Bloco de Lógica Sequencial (Saídas e Próximo Estado) ---
    always_ff @(posedge clk or posedge rst) begin: FSM
        if (rst) begin
            // Valores padrão no reset
            data_setup_reg.bip_status      <= 1'b1; 
            data_setup_reg.bip_time        <= 5;
            data_setup_reg.tranca_aut_time <= 5; 
            data_setup_reg.master_pin      <= '{status:1'b1, digit1:4'h1, digit2:4'h2, digit3:4'h3, digit4:4'h4}; 
            data_setup_reg.pin1            <= '{status:1'b1, digit1:4'h0, digit2:4'h0, digit3:4'h0, digit4:4'h0}; 
            data_setup_reg.pin2 <= '{default:'0};
            data_setup_reg.pin3 <= '{default:'0};
            data_setup_reg.pin4 <= '{default:'0};
            
            // Inicialização de saídas e contadores
            tranca <= 1'b1;
            bip <= 1'b0;
            setup_on <= 1'b0;
            enable <= 1'b0;
            contador_falhas <= 0;
            contagem_espera <= 0;
            contagem_travamento <= 0;
            contagem_bip <= 0;
            next_state <= RESET;
            bcd_out <= '{default:'hB}; // 'C' para apagar ou traço, depende do driver
            bcd_enable <= 1'b1;
            

        end else begin
            // --- Valores Padrão para cada ciclo ---
            enable <= 1'b0;
            bcd_enable <= 1'b0; 
            
            case(next_state)
                
                RESET: begin
                    bcd_out <= '{default:'hB}; // 'C' para apagar ou traço, depende do driver
                    bcd_enable <= 1'b1;
                    tranca <= 1'b1; // Mantém travado no reset
                    if(!sensor_de_contato) begin
                        next_state <= MONTAR_PIN;
                    end
                    else next_state <= next_state;
                end

                MONTAR_PIN: begin
                    bcd_out.BCD3 <= pin_sinal_interno.digit1;
                    bcd_out.BCD2 <= pin_sinal_interno.digit2;
                    bcd_out.BCD1 <= pin_sinal_interno.digit3;
                    bcd_out.BCD0 <= pin_sinal_interno.digit4;
                    bcd_enable <= 1'b1;
                    tranca <= 1'b1;
                    enable <= 1'b0; // Mantém o módulo de update habilitado
                    if(botao_pressionado_pulso) begin
                        tranca <= 0;
                        next_state <= TRAVA_OFF;
                    end else if (pin_sinal_interno.status) begin // FIX: Aguarda um PIN completo
                        next_state <= VERIFICAR_SENHA;
                    end
                    else next_state <= next_state;
                end

                VERIFICAR_SENHA: begin
                    if(update_master) begin
                        enable <= 1'b1; // Habilita o módulo de update
                        next_state <= UPDATE_MASTER;
                    end
                    else if (senha_fail) begin
                        contador_falhas <= contador_falhas + 1;
                        // Se atingiu o limite, vai para o bloqueio, senão tenta de novo
                        if (contador_falhas >= MAX_FALHAS) begin
                            contagem_espera <= 0; // Inicia timer de espera
                            next_state <= ESPERA;
                        end else begin
                            next_state <= MONTAR_PIN; // Volta para tentar de novo
                        end
                    end
                    else if(senha_padrao) begin
                        contador_falhas <= 0;
                        tranca <= 0;
                        next_state <= TRAVA_OFF;
                    end
                    else if (!update_master) begin
                          setup_on <= 1'b1; // Habilita o modo de configuração
                          
                          contador_falhas <= 0;
                          next_state <= SETUP;
                      end
                    
                    else next_state <= next_state;
                end

                ESPERA: begin
                    
                    bcd_out <= '{default:'hA}; // 'C' para apagar ou traço, depende do driver
                    bcd_enable <= 1'b1;
                    // FIX: Lógica de bloqueio temporário
                    tranca <= 1'b1; // Permanece travado
                    if (contagem_espera < (TEMPO_ESPERA_SEGUNDOS * CLK_FREQ_HZ)) begin
                        contagem_espera <= contagem_espera + 1;
                    end 
                    else begin
                        contador_falhas <= 0; // Zera as falhas
                        next_state <= MONTAR_PIN; // Volta à operação normal
                    end
                end

                UPDATE_MASTER: begin
                    bcd_out.BCD3 <= pin_sinal_interno.digit1;
                    bcd_out.BCD2 <= pin_sinal_interno.digit2;
                    bcd_out.BCD1 <= pin_sinal_interno.digit3;
                    bcd_out.BCD0 <= pin_sinal_interno.digit4;
                    bcd_enable <= 1'b1;
                    // FIX: Lógica para atualizar o PIN mestre
                    enable <= 1'b1; // Mantém o módulo de update habilitado
                    if (novo_master_pin_sinal.status) begin // Aguarda o novo PIN ser montado
                        data_setup_reg.master_pin <= novo_master_pin_sinal; // Atualiza o registrador                      	
                        next_state <= MONTAR_PIN;
                    end
                    else next_state <= next_state;
                end

                SETUP: begin
                    setup_on <= 1'b1; // Mantém o sinal ativo
                    if(!setup_end) begin
                        data_setup_reg <= data_setup_new; // FIX: Carrega a nova configuração
                        setup_on <= 0;
                        next_state <= MONTAR_PIN;
                    end
                    else next_state <= next_state;
                end
                
                TRAVA_OFF: begin
                    
                    bcd_out <= '{default:'hB};
                    bcd_enable <= 1'b1;
                    next_state <= PORTA_FECHADA;
                end
                TRAVA_ON: begin
                    contagem_travamento <= 0;
                    next_state <= MONTAR_PIN;
                end
                
                PORTA_FECHADA: begin
                    if (sensor_de_contato) begin
                        contagem_travamento <= 0;
                        next_state <= PORTA_ABERTA;
                    end
                    else if ((contagem_travamento >= (data_setup_reg.tranca_aut_time * CLK_FREQ_HZ)) || botao_pressionado_pulso) begin
                        tranca <= 1'b1;
                        next_state <= TRAVA_ON;
                    end
                    else begin
                        contagem_travamento <= contagem_travamento + 1;
                        next_state <= next_state; 
                    end
                end

                PORTA_ABERTA: begin
                    if (!sensor_de_contato) begin
                        contagem_bip <= 0;
                        contagem_travamento <= 0; 
                        bip <= 0;
                        next_state <= PORTA_FECHADA;
                    end
                    else begin
                        if (contagem_bip < (data_setup_reg.bip_time * CLK_FREQ_HZ)) begin 
                            contagem_bip <= contagem_bip + 1;
                        end
                        if ((contagem_bip >= (data_setup_reg.bip_time * CLK_FREQ_HZ)) && data_setup_reg.bip_status) begin
                            bip <= 1;
                        end
                        next_state <= next_state;
                    end
                end

                default: next_state <= RESET;

            endcase
        end
    end: FSM

endmodule

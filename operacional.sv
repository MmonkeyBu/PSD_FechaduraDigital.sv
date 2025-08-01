
module operacional (
		input 	logic 		clk, 
		input 	logic 		rst, 
		input 	logic 		sensor_de_contato, 
		input 	logic 		botao_interno,
		input 	logic 		key_valid,
		input		logic [3:0] key_code,
		output 	bcdPac_t 	bcd_out,
		output 	logic 		bcd_enable,
		output 	logic			tranca, 
		output 	logic 		bip,
		output 	logic 		setup_on,
		input		logic 		setup_end,
		output 	setupPac_t  data_setup_old,
		input 	setupPac_t  data_setup_new
		 );
    //----------------------------------------------------------------
    // 1. Definição dos Estados da Máquina de Estados
    //----------------------------------------------------------------
    typedef enum logic [3:0] {
        S_RESET,
        S_MONTAR_PIN,
        S_VERIFICAR_SENHA,
        S_ESPERA,
        S_UPDATE_MASTER,
        S_SETUP,
        S_TRAVA_OFF,
        S_PORTA_FECHADA,
        S_PORTA_ABERTA,
        S_TRAVA_ON
    } state_t;

    state_t current_state, next_state;

    //----------------------------------------------------------------
    // 2. Sinais e Registradores Internos
    //----------------------------------------------------------------

    // Sinais de comunicação com submódulos
    pinPac_t pin_montado;
    logic    senha_fail, senha_padrao, senha_master, senha_master_update_status;

    // Registradores de dados e flags
    setupPac_t data_setup_reg; // Armazena a configuração atual
    logic      senha_master_update_reg;
    logic [3:0] contador_falhas_reg;

    // Contadores para timers
    logic [31:0] timer_reg; // Timer genérico para espera, bip e travamento

    // Registradores para as saídas
    logic      tranca_reg, bip_reg, setup_on_reg;
    bcdPac_t   bcd_out_reg;
    logic      bcd_enable_reg;

    // Variáveis para os limites dos timers (em ciclos de clock)
    logic [31:0] tempo_espera, tempo_travamento, tempo_bip;


    //----------------------------------------------------------------
    // 3. Instanciação dos Submódulos
    //----------------------------------------------------------------

    montar_pin u_montar_pin (
        .clk        (clk),
        .rst        (rst),
        .key_valid  (key_valid),
        .key_code   (key_code),
        .pin_out    (pin_montado)
    );

    verificar_senha u_verificar_senha (
        .clk                  (clk),
        .rst                  (rst),
        .pin_in               (pin_montado), // Vem do montar_pin
        .data_setup           (data_setup_reg), // Usa a configuração atual
        .senha_fail           (senha_fail),
        .senha_padrao         (senha_padrao),
        .senha_master         (senha_master),
        .senha_master_update  (senha_master_update_status) // Indica se o PIN mestre é o padrão pós-reset
    );

    //----------------------------------------------------------------
    // 4. Lógica Combinacional (Define próximas ações)
    //----------------------------------------------------------------
    always_comb begin
        // Valores padrão para evitar latches
        next_state = current_state;
        bip_reg = 1'b0;
        setup_on_reg = 1'b0;
        bcd_enable_reg = 1'b0;
        // Manter saídas e registradores por padrão
        tranca_reg = tranca;
        // ... outros valores padrão ...

        case (current_state)
            S_RESET: begin
                // Conforme o diagrama, espera a porta fechar para iniciar
                if (sensor_de_contato) begin
                    next_state = S_MONTAR_PIN;
                    tranca_reg = 1'b1; // Trava a porta ao iniciar
                end else begin
                    next_state = S_RESET;
                    tranca_reg = 1'b0; // Permanece destravada
                end
            end

            S_MONTAR_PIN: begin
                // Mostra o PIN sendo digitado
                bcd_out_reg.BCD3 = pin_montado.digit1;
                bcd_out_reg.BCD2 = pin_montado.digit2;
                bcd_out_reg.BCD1 = pin_montado.digit3;
                bcd_out_reg.BCD0 = pin_montado.digit4;
                bcd_enable_reg = 1'b1;

                if (pin_montado.status) begin // Tecla '*' foi pressionada
                    next_state = S_VERIFICAR_SENHA;
                end
            end

            S_VERIFICAR_SENHA: begin
                if (senha_padrao) begin
                    next_state = S_TRAVA_OFF;
                    tranca_reg = 1'b0; // Destrava
                end else if (senha_master && senha_master_update_reg) begin
                    next_state = S_SETUP;
                    setup_on_reg = 1'b1; // Ativa o modo setup
                end else if (senha_master && !senha_master_update_reg) begin
                    // Senha mestre padrão foi inserida, precisa atualizar
                    next_state = S_UPDATE_MASTER; // Este estado não está no diagrama, mas é uma boa prática
                                                  // O diagrama vai direto para Montar PIN após o update
                end else if (senha_fail) {
                    next_state = S_ESPERA;
                end
            end

            S_ESPERA: begin
                // Mostra "------" no display
                bcd_out_reg = '{default:'hC}; // 'C' para apagar ou traço, depende do driver
                bcd_enable_reg = 1'b1;
                if (timer_reg >= tempo_espera) begin
                    next_state = S_MONTAR_PIN;
                end
            end
            
            S_SETUP: begin
                // Módulo operacional aguarda o fim do setup
                if (setup_end) begin
                    next_state = S_MONTAR_PIN;
                end
            end

            S_TRAVA_OFF: begin
                next_state = S_PORTA_FECHADA; // Próximo estado é verificar a porta
            end

            S_PORTA_FECHADA: begin
                if (!sensor_de_contato) begin // Porta abriu
                    next_state = S_PORTA_ABERTA;
                end else if (timer_reg >= tempo_travamento || botao_interno) begin
                    next_state = S_TRAVA_ON;
                    tranca_reg = 1'b1; // Trava
                end
            end

            S_PORTA_ABERTA: begin
                if (sensor_de_contato) begin // Porta fechou
                    next_state = S_PORTA_FECHADA;
                end else if (timer_reg >= tempo_bip && data_setup_reg.bip_status) begin
                    bip_reg = 1'b1; // Aciona o bip
                end
            end

            S_TRAVA_ON: begin
                next_state = S_MONTAR_PIN; // Volta a aguardar PIN
            end

            // Estado para atualização do Master PIN (implícito no diagrama)
            S_UPDATE_MASTER: begin
                // Lógica para mostrar "UPDT" e aguardar novo master pin
                // ... (a lógica exata dependeria do módulo update_master)
                // Ao final do update, o diagrama sugere voltar a Montar PIN.
                // update_master_end seria a condição de saída
                next_state = S_MONTAR_PIN;
            end

            default: next_state = S_RESET;
        endcase
    end

    //----------------------------------------------------------------
    // 5. Lógica Sequencial (Atualiza estados e registradores)
    //----------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Estado inicial e reset de todos os regs
            current_state <= S_RESET;
            tranca <= 1'b0;
            bip <= 1'b0;
            setup_on <= 1'b0;
            bcd_enable <= 1'b0;
            contador_falhas_reg <= 4'b0;
            senha_master_update_reg <= 1'b0; // Assume que precisa atualizar após reset
            timer_reg <= 32'b0;
            // Carrega configurações padrão no reset
            data_setup_reg.bip_status <= 1'b1;
            data_setup_reg.bip_time <= 7'd5;
            data_setup_reg.tranca_aut_time <= 7'd5;
            // ... resetar PINs para o padrão ...
        end else begin
            // Transição de estado
            current_state <= next_state;

            // Atualiza saídas registradas
            tranca <= tranca_reg;
            bip <= bip_reg;
            setup_on <= setup_on_reg;
            bcd_out <= bcd_out_reg;
            bcd_enable <= bcd_enable_reg;

            // Lógica de atualização dos contadores e flags
            if (current_state != next_state) begin
                timer_reg <= 32'b0; // Reseta o timer em cada transição de estado
            end else begin
                timer_reg <= timer_reg + 1; // Incrementa o timer
            end

            // Atualiza contador de falhas
            if (next_state == S_ESPERA && current_state != S_ESPERA)
                contador_falhas_reg <= contador_falhas_reg + 1;
            else if (senha_padrao) // Zera com acerto
                contador_falhas_reg <= 4'b0;

            // Atualiza flag do master PIN
            if (senha_master_update_status) // Se o verificar_senha indicar que o update foi feito
                senha_master_update_reg <= 1'b1;

            // Recebe novas configurações do modo setup
            if (setup_end)
                data_setup_reg <= data_setup_new;
        end
    end

    //----------------------------------------------------------------
    // 6. Atribuições contínuas
    //----------------------------------------------------------------

    // Converte tempos configurados (em segundos) para ciclos de clock
    assign tempo_bip = data_setup_reg.bip_time * CLK_FREQ;
    assign tempo_travamento = data_setup_reg.tranca_aut_time * CLK_FREQ;

    // Define o tempo de espera baseado no número de falhas
    // (conforme documento, 1s, 10s, 20s, 30s)
    assign tempo_espera = (contador_falhas_reg < 3)  ? (1 * CLK_FREQ) :
                          (contador_falhas_reg == 3) ? (10 * CLK_FREQ) :
                          (contador_falhas_reg == 4) ? (20 * CLK_FREQ) :
                                                       (30 * CLK_FREQ);

    // Passa a configuração atual para o módulo de setup quando ativado
    assign data_setup_old = data_setup_reg;

endmodule

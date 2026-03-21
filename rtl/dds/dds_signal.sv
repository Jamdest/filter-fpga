`timescale 1ns / 1ps

//------------------------------------------------------------------------------
module dds_signal #(
    parameter int START_FREQ     = 32'h147A_E147, // Несущая / Начальная частота
    parameter int STOP_FREQ      = 32'h3333_3333, // Конечная частота (для ЛЧМ)
    parameter int STEP_FREQ      = 32'h0000_2710, // Шаг перестройки (для ЛЧМ)
    
    // Новые параметры для управления импульсом:
    parameter int PULSE_DURATION = 32'd10000,     // Длительность импульса в тактах
    parameter string MODULATION  = "LFM"          // Тип: "LFM" (ЛЧМ) или "CW" (одна частота)
) (
    input  logic clk,
    input  logic rst,
    input  logic i_btn_start,
    
    // Выходные сигналы
    output logic [13:0] o_sine,
    output logic [13:0] o_cosine,
    output logic [15:0] o_phase,
    output logic        o_pulse_valid             // Флаг активного импульса (огибающая)
);

    // Служебные сигналы DDS
    logic [63:0] cfg_tdata;  // Данные конфигурации
    logic        cfg_valid;  // Валидность конфигурации
    logic [31:0] data_dds_out; // Выход DDS (cosine + sine)
    logic        aresetn;

    // FSM
    typedef enum logic [1:0] {
        ST_IDLE  = 2'b00,
        ST_RUN   = 2'b01,
        ST_DONE  = 2'b10
    } state_t;
    
    state_t state;
    
    logic [31:0] pinc_curr;
    logic [31:0] timer;

    assign aresetn = ~rst;
    
    // Формирование конфигурации для DDS (Phase Increment)
    assign cfg_tdata = {32'h0000_0000, pinc_curr};

    // Инстанс стандартного IP-ядра DDS
    dds_compiler_0 dds_0 (
        .aclk                  (clk),
        .aresetn               (aresetn),
        .s_axis_config_tdata   (cfg_tdata),
        .s_axis_config_tvalid  (cfg_valid),
        .m_axis_data_tdata     (data_dds_out),
        .m_axis_phase_tdata    (o_phase)
    );
    
    // Логика выходных сигналов
    // Строб: активен только когда генератор в состоянии RUN (идет импульс)
    assign o_pulse_valid = (state == ST_RUN);
    
    // Привязываем синус и косинус, обнуляя их вне импульса
    assign o_sine   = o_pulse_valid ? data_dds_out[13:0]  : 14'd0;
    assign o_cosine = o_pulse_valid ? data_dds_out[29:16] : 14'd0;

    // Логика конечного автомата и генерации
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= ST_IDLE;
            pinc_curr <= START_FREQ;
            cfg_valid <= 1'b0;
            timer     <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    cfg_valid <= 1'b0;
                    timer     <= '0;
                    pinc_curr <= START_FREQ;
                    
                    if (i_btn_start) begin
                        state     <= ST_RUN;
                        cfg_valid <= 1'b1; // Применяем начальную частоту
                    end
                end

                ST_RUN: begin
                    if (timer < PULSE_DURATION - 1) begin
                        timer <= timer + 1'b1;
                        
                        // Логика модуляции частоты
                        if (MODULATION == "LFM") begin
                            if (pinc_curr < STOP_FREQ) begin
                                pinc_curr <= pinc_curr + STEP_FREQ;
                                cfg_valid <= 1'b1; // Отсылаем обновленную частоту
                            end else begin
                                cfg_valid <= 1'b0; // Частота достигла пика, дожидаемся конца импульса
                            end
                        end else if (MODULATION == "CW") begin
                            // Для Continuous Wave частота постоянна
                            cfg_valid <= 1'b0; 
                        end
                    end else begin
                        state     <= ST_DONE;
                        cfg_valid <= 1'b0;
                    end
                end

                ST_DONE: begin
                    // Защита от перезапуска, пока кнопка старта не отжата
                    if (!i_btn_start) begin
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
        
endmodule
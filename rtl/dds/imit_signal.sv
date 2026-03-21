`timescale 1ns / 1ps

module imit_signal #(
    parameter int START_FREQ     = 32'h0000,
    parameter int STOP_FREQ      = 32'hFFFF,
    parameter int STEP           = 32'h0100,
    parameter int DWELL_CYCLES   = 50_000,
    parameter string MOD         = "linear",   // "linear" (ЛЧМ) или "none" (CW)
    parameter string MODULATION  = "am",       // "am" (АМ) или "none"
    parameter int AM_STEP        = 32'd50,
    parameter int AM_DEPTH_Q15   = 16'd16384   // Глубина АМ модуляции, формат Q15
)(
    input  logic clk,
    input  logic rst,
    input  logic i_btn_start,
    
    // Формат: [1:0] для двух каналов (I и Q / косинус и синус), каждый по 14 бит
    output logic [1:0][13:0] o_data,
    output logic [15:0] o_phase,
    output logic o_valid_data,
    output logic o_valid_phase
);

    logic btn_rise;
    logic cfg_valid;
    logic [15:0] pinc;
    logic [15:0] poff;
    logic [31:0] dds_data;
    logic [15:0] dds_phase;

    // Сигналы амплитудной модуляции
    logic [15:0] env_q15;
    logic env_up;

    // Автомат состояний
    typedef enum logic [1:0] {
        IDLE = 2'd0,
        RUN  = 2'd1,
        DONE = 2'd2
    } state_t;
    
    state_t state;
    logic [31:0] timer;

    // Выделение переднего фронта кнопки запуска
    sync_pulse u_btn (
        .clk(clk),
        .rst(rst),
        .i_async(i_btn_start),
        .o_rise_pulse(btn_rise)
    );

    // Экземпляр DDS (генератор несущей / ЛЧМ)
    dds_wrapper u_dds (
        .clk(clk),
        .rst(rst),
        .i_pinc(pinc),
        .i_poff(poff),
        .i_cfg_valid(cfg_valid),
        .o_data(dds_data),
        .o_phase(dds_phase)
    );

    // Управление частотой и амплитудой (генерация огибающих)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            pinc      <= START_FREQ[15:0];
            poff      <= '0;
            cfg_valid <= 1'b0;
            timer     <= '0;
            env_q15   <= 16'd32767; // Максимальная амплитуда
            env_up    <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    timer     <= '0;
                    cfg_valid <= 1'b0;
                    pinc      <= START_FREQ[15:0];
                    
                    // Инициализация стартовой глубины АМ
                    if (MODULATION == "am") begin
                        env_q15 <= 16'd32767 - AM_DEPTH_Q15;
                        env_up  <= 1'b1;
                    end else begin
                        env_q15 <= 16'd32767;
                    end

                    if (btn_rise) begin
                        state     <= RUN;
                        cfg_valid <= 1'b1; // Отсылаем частоту в DDS
                    end
                end

                RUN: begin
                    if (timer < DWELL_CYCLES - 1) begin
                        timer <= timer + 1'b1;
                        
                        // 1. Частотная модуляция (ЛЧМ)
                        if (MOD == "linear") begin
                            if (pinc < STOP_FREQ[15:0]) begin
                                pinc      <= pinc + STEP[15:0];
                                cfg_valid <= 1'b1; // DDS обновляет инкремент фазы
                            end else begin
                                cfg_valid <= 1'b0;
                            end
                        end else begin
                            cfg_valid <= 1'b0; // Одна частота (CW)
                        end
                        
                        // 2. Амплитудная модуляция (генерируем пилообразную/треугольную огибающую)
                        if (MODULATION == "am") begin
                            if (env_up) begin
                                if (env_q15 + AM_STEP < 32767) begin
                                    env_q15 <= env_q15 + AM_STEP;
                                end else begin
                                    env_up  <= 1'b0;
                                    env_q15 <= env_q15 - AM_STEP;
                                end
                            end else begin
                                if (env_q15 > (16'd32767 - AM_DEPTH_Q15) + AM_STEP) begin
                                    env_q15 <= env_q15 - AM_STEP;
                                end else begin
                                    env_up  <= 1'b1;
                                    env_q15 <= env_q15 + AM_STEP;
                                end
                            end
                        end

                    end else begin
                        state     <= DONE;
                        cfg_valid <= 1'b0;
                    end
                end

                DONE: begin
                    // Ожидание отжатия кнопки, защита от дребезга
                    if (!i_btn_start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Применение АМ огибающей и пересчет данных
    // dds_data содержит 2 канала (стандарт для DDS compiler Xilinx):
    // [13:0] - sine (channel 1)
    // [29:16] - cosine (channel 2)
    
    logic signed [14:0] raw_sine;
    logic signed [14:0] raw_cosine;
    
    // Приводим выходы DDS к знаковому виду для правильного умножения
    assign raw_sine   = $signed({dds_data[13], dds_data[13:0]});
    assign raw_cosine = $signed({dds_data[29], dds_data[29:16]});

    logic signed [16:0] signed_env;
    assign signed_env = $signed({1'b0, env_q15}); // Q15 без знака, делаем положительным знаковым

    logic signed [31:0] mult_sine;
    logic signed [31:0] mult_cosine;

    // Пайплайн умножения для АМ
    always_ff @(posedge clk) begin
        if (state == RUN) begin
            mult_sine     <= raw_sine * signed_env;
            mult_cosine   <= raw_cosine * signed_env;
            o_valid_data  <= 1'b1;
            o_valid_phase <= 1'b1;
        end else begin
            mult_sine     <= '0;
            mult_cosine   <= '0;
            o_valid_data  <= 1'b0;
            o_valid_phase <= 1'b0;
        end
    end

    // mult_sine имеет формат (Q14 * Q15) = Q29
    // Отсекаем нижние 15 бит (Q15), чтобы вернуть формат к оригинальной амплитуде
    assign o_data[0] = mult_sine[28:15];   // Канал 0 (sine)
    assign o_data[1] = mult_cosine[28:15]; // Канал 1 (cosine)
    
    // Пропуск фазы наружу
    assign o_phase   = dds_phase;

endmodule
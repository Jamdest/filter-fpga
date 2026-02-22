`timescale 1ns / 1ps

module tb_am();

    // Сигналы управления
    reg clk;
    reg rst;
    reg i_btn_start;

    // Выходные сигналы
    wire [15:0] o_data;
    wire [15:0] o_phase;
    wire o_valid_data;
    wire o_valid_phase;

    // Тактовый сигнал 50 МГц
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Настройка модуля для выраженной AM
    imit_signal #(
        .START_FREQ(32'h0500),   // Постоянная несущая частота
        .STEP(32'h0000),         // Свип отключен (шаг 0)
        .MODULATION("am"),       // AM включена
        .AM_STEP(32'h04000000),  // Высокая скорость AM для быстрой проверки
        .AM_DEPTH_Q15(16'd26214) // Глубина ~80%
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_btn_start(i_btn_start),
        .o_data(o_data),
        .o_phase(o_phase),
        .o_valid_data(o_valid_data),
        .o_valid_phase(o_valid_phase)
    );

    // Сценарий симуляции
    initial begin
        rst = 1;
        i_btn_start = 0;
        #100;
        rst = 0;
        #100;

        // Запуск генерации
        i_btn_start = 1;
        #40;
        i_btn_start = 0;

        // Симуляция достаточного времени для отображения нескольких периодов огибающей
        #50000;
        $finish;
    end

endmodule
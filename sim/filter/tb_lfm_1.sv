`timescale 1ns / 1ps

module tb_lfm_1();

    localparam T_CLK = 10; // 100 MHz

    reg         clk;
    reg         rst;
    reg         i_btn_start;
    
    wire [13:0] o_sine;
    wire [13:0] o_cosine;
    wire [15:0] o_phase;

    // DUT
    dds_signal #(
        .START_FREQ (32'h147a_e147), // 
        .STOP_FREQ  (32'h3333_3333), // 
        .STEP_FREQ  (32'h0001_0000)  
    ) dut (
        .clk        (clk),
        .rst        (rst),
        .i_btn_start(i_btn_start),
        .o_sine     (o_sine),
        .o_cosine   (o_cosine),
        .o_phase    (o_phase)
    );

    // Генерация тактов
    initial begin
        clk = 0;
        forever #(T_CLK/2) clk = ~clk;
    end

    // Сценарий
    initial begin
        rst = 1;
        i_btn_start = 0;
        #(T_CLK * 10);
        rst = 0;
        #(T_CLK * 20);
        
        // Одиночный запуск по кнопке
        $display("Sending Start Pulse...");
        @(posedge clk);
        i_btn_start = 1;
        @(posedge clk);
        i_btn_start = 0;

        // Никаких $finish и $stop. 
        // Симуляция будет крутиться вечно, пока сам не нажмешь "Stop" в GUI.
    end

endmodule
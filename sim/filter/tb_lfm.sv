`timescale 1ns / 1ps

module tb_lfm();

    localparam T_CLK  = 10;          // 100 MHz
    localparam CLK_HZ = 100_000_000; 

    reg         clk;
    reg         rst;
    reg         i_btn_start;
    
    wire [13:0] o_sine;
    wire [13:0] o_cosine;
    wire [15:0] o_phase;

    // DUT
    dds_signal #(
        .START_FREQ (32'h147A_E147), 
        .STOP_FREQ  (32'h3333_3333), 
        .STEP_FREQ  (32'h0000_0200)  
    ) dut (
        .clk        (clk),
        .rst        (rst),
        .i_btn_start(i_btn_start),
        .o_sine     (o_sine),
        .o_cosine   (o_cosine),
        .o_phase    (o_phase)
    );

    // Функция пересчета (только для симуляции)
    function real get_freq_hz(input [31:0] pinc);
        return (real'(pinc) * CLK_HZ) / (2.0**32);
    endfunction

    // Переменная для отображения частоты на Waveform
    real freq_monitor_hz;
    always_comb freq_monitor_hz = get_freq_hz(dut.pinc_curr);

    // Такты
    initial begin
        clk = 0;
        forever #(T_CLK/2) clk = ~clk;
    end

    // Сценарий
    initial begin
        rst         = 1;
        i_btn_start = 0;
        #(T_CLK * 10);
        rst         = 0;
        #(T_CLK * 20);
        
        $display("--- Start Sweep ---");
        @(posedge clk);
        i_btn_start = 1;
        @(posedge clk);
        i_btn_start = 0;

        // Мониторинг в консоль
        forever begin
            @(posedge clk);
            if (dut.state == 2'b10) begin // ST_SWEEP
                $display("Time: %t | Frequency: %0.2f MHz", $time, freq_monitor_hz / 1_000_000.0);
            end
        end
    end

endmodule
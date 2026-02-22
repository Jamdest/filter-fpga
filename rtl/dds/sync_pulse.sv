`timescale 1ns / 1ps


module sync_pulse (
    input  wire clk,
    input  wire rst,
    input  wire i_async,
    output wire o_sync,
    output wire o_rise_pulse,
    output wire o_fall_pulse
);
    reg ff1;
    reg ff2;
    reg ff3;

    // Трехкаскадная синхронизация для устранения метастабильности
    always_ff @(posedge clk) begin
        if (rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
            ff3 <= 1'b0;
        end else begin
            ff1 <= i_async;
            ff2 <= ff1;
            ff3 <= ff2;
        end
    end

    assign o_sync = ff2;
    // Выделение переднего фронта на стабильных триггерах
    assign o_rise_pulse = ff2 & ~ff3;
    // Выделение заднего фронта
    assign o_fall_pulse = ~ff2 & ff3;

endmodule
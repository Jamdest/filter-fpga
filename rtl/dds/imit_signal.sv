`timescale 1ns / 1ps

module imit_signal #(
    parameter [31:0] START_FREQ = 32'h0000,
    parameter [31:0] STOP_FREQ = 32'hFFFF,
    parameter [31:0] STEP = 32'h0100,
    parameter integer DWELL_CYCLES = 50_000,
    parameter string MOD = "linear",
    parameter string MODULATION = "am",
    parameter [31:0] AM_STEP = 32'd85899,
    parameter [15:0] AM_DEPTH_Q15 = 16'd16384
)(
    input  wire clk,
    input  wire rst,
    input  wire i_btn_start,
    output wire [13:0][1:0] o_data,
    output wire [15:0] o_phase,
    output wire o_valid_data,
    output wire o_valid_phase
);
    wire btn_rise;
    wire running;
    wire cfg_valid;
    wire [15:0] pinc;
    wire [15:0] poff;
    wire [15:0] dds_data;
    wire [15:0] dds_phase;
    wire [15:0] env_q15;
    wire [15:0] am_data;

    // Обработка кнопки запуска
    sync_pulse u_btn (
        .clk(clk),
        .rst(rst),
        .i_async(i_btn_start),
        .o_rise_pulse(btn_rise)
    );

    // Управление частотой DDS


    // Экземпляр DDS (генератор несущей)
    dds_wrapper u_dds (
        .clk(clk),
        .rst(rst),
        .i_pinc(pinc),
        .i_poff(poff),
        .i_cfg_valid(cfg_valid),
        .o_data(dds_data),
        .o_phase(dds_phase)
    );

endmodule
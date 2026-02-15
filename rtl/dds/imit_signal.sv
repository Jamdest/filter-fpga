`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: imit_signal (TOP)
// Purpose:
//   - Button-controlled signal generator for FIR filter testing
//   - DDS produces a sine (or configured waveform) with programmable FTW
//   - Optional AM modulation is applied AFTER DDS output (safe, lightweight)
// Outputs:
//   - o_data  : 16-bit sample stream (optionally AM-modulated)
//   - o_phase : DDS phase (debug / optional use)
//   - o_valid_data / o_valid_phase : high while running
//------------------------------------------------------------------------------
module imit_signal #(
    parameter [31:0] START_FREQ    = 32'h0000,
    parameter [31:0] STOP_FREQ     = 32'hFFFF,
    parameter [31:0] STEP          = 32'h0100,
    parameter integer DWELL_CYCLES = 50_000,
    parameter string MOD           = "linear",

    // Modulation selection: "none" or "am"
    parameter string MODULATION    = "am",

    // AM parameters
    parameter [31:0] AM_STEP       = 32'd85899,
    parameter [15:0] AM_DEPTH_Q15  = 16'd16384
)(
    input  wire clk, // 50 MHz
    input  wire rst,
    input  wire i_btn_start,

    output wire [15:0] o_data,
    output wire [15:0] o_phase,
    output wire        o_valid_data,
    output wire        o_valid_phase
);

    localparam bit MOD_AM = (MODULATION == "am");

    // --- button sync + rising edge pulse
    wire btn_sync;
    wire btn_rise;
    wire btn_fall;

    sync_pulse u_btn (
        .clk          (clk),
        .rst          (rst),
        .i_async      (i_btn_start),
        .o_sync       (btn_sync),
        .o_rise_pulse (btn_rise),
        .o_fall_pulse (btn_fall)
    );

    // --- sweep controller -> pinc/poff + cfg_valid strobe
    wire        running;
    wire [15:0] pinc;
    wire [15:0] poff;
    wire        cfg_valid;

    sweep_ctrl #(
        .START_FREQ    (START_FREQ),
        .STOP_FREQ     (STOP_FREQ),
        .STEP          (STEP),
        .DWELL_CYCLES  (DWELL_CYCLES),
        .MOD           (MOD)
    ) u_sweep (
        .clk           (clk),
        .rst           (rst),
        .i_start_pulse (btn_rise),
        .o_running     (running),
        .o_pinc        (pinc),
        .o_poff        (poff),
        .o_cfg_valid   (cfg_valid)
    );

    // --- DDS wrapper
    wire [15:0] dds_data_u;
    wire [15:0] dds_phase_u;

    dds_wrapper u_dds (
        .clk         (clk),
        .rst         (rst),
        .i_pinc      (pinc),
        .i_poff      (poff),
        .i_cfg_valid (cfg_valid),
        .o_data      (dds_data_u),
        .o_phase     (dds_phase_u)
    );

    // --- AM envelope + AM modulator
    wire [15:0] env_q15;

    am_envelope_nco #(
        .AM_STEP   (AM_STEP),
        .DEPTH_Q15 (AM_DEPTH_Q15)
    ) u_env (
        .clk      (clk),
        .rst      (rst),
        .i_enable (running),
        .o_env_q15(env_q15)
    );

    wire signed [15:0] dds_data_s = dds_data_u;
    wire signed [15:0] am_data_s;

    am_modulator u_am (
        .clk       (clk),
        .rst       (rst),
        .i_enable  (MOD_AM & running),
        .i_x       (dds_data_s),
        .i_env_q15 (env_q15),
        .o_y       (am_data_s)
    );

    // Output selection (ternary)
    assign o_data  = (MOD_AM) ? $unsigned(am_data_s) : dds_data_u;
    assign o_phase = dds_phase_u;

    // Valids: keep simple "running" gating for downstream FIR
    assign o_valid_data  = running;
    assign o_valid_phase = running;

endmodule

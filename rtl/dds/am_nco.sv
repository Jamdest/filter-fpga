`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: am_envelope_nco
// Purpose:
//   - Generate an amplitude envelope for AM in Q1.15 format (0..32767)
//   - Uses a 32-bit phase accumulator as an NCO
//   - Produces a triangle waveform (0..1..0) then mixes with depth:
//       env = (1 - depth) + depth * tri
// Parameters:
//   AM_STEP       : NCO phase increment for envelope
//                  f_env = AM_STEP * Fclk / 2^32
//   DEPTH_Q15     : 0..32767 (0=no AM, 32767=100% depth)
// Notes:
//   - Triangle is derived from sawtooth using MSB mirroring.
//------------------------------------------------------------------------------
module am_envelope_nco #(
    parameter [31:0] AM_STEP   = 32'd85899,   // ~1 kHz at 50 MHz clock
    parameter [15:0] DEPTH_Q15 = 16'd16384    // 50% depth
)(
    input  wire        clk,
    input  wire        rst,      // active-high synchronous reset
    input  wire        i_enable, // envelope runs only when enabled
    output wire [15:0] o_env_q15 // Q1.15 envelope (0..32767)
);

    reg [31:0] acc;

    always @(posedge clk) begin
        if (rst) begin
            acc <= 32'd0;
        end else begin
            // If disabled, keep envelope phase at 0 for deterministic restart
            acc <= (i_enable) ? (acc + AM_STEP) : 32'd0;
        end
    end

    // Sawtooth from accumulator upper bits
    wire [15:0] saw = acc[31:16];

    // Triangle generation:
    // If MSB of accumulator is 1, mirror the saw -> triangle down slope.
    wire [15:0] tria = (acc[31]) ? ~saw : saw; // ternary operator

    // Envelope mix:
    // env = (1 - depth) + depth * tri
    // Everything in Q1.15, tri is interpreted as 0..65535 but effectively 0..32767 amplitude.
    // We use 32767 as "1.0" in Q1.15 to avoid hitting sign bit.
    wire [31:0] mul     = DEPTH_Q15 * tria;        // 16x16 -> 32
    wire [15:0] mul_q15 = mul[30:15];             // >>15 (Q1.15)

    wire [15:0] base_q15 = 16'd32767 - DEPTH_Q15; // (1 - depth) in Q1.15

    assign o_env_q15 = base_q15 + mul_q15;

endmodule

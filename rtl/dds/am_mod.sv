`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: am_modulator
// Purpose:
//   - Apply amplitude modulation to a signed 16-bit signal:
//       y = x * env (env in Q1.15)
//   - Output remains signed 16-bit.
// Notes:
//   - Since env <= 1.0, the output magnitude will not exceed input magnitude.
//   - Includes simple rounding when shifting back by 15.
//------------------------------------------------------------------------------
module am_modulator (
    input  wire              clk,
    input  wire              rst,       // active-high synchronous reset
    input  wire              i_enable,  // when 0, output is passthrough
    input  wire signed [15:0] i_x,
    input  wire        [15:0] i_env_q15,
    output wire signed [15:0] o_y
);

    // Multiply (signed x) by (unsigned env). env is always positive.
    wire signed [31:0] prod = i_x * $signed({1'b0, i_env_q15});

    // Rounding: add 0.5 LSB before >>15 (only valid for positive, but env>=0 and sign is in i_x)
    // For simplicity we do symmetric rounding by adding sign-dependent bias.
    wire signed [31:0] bias = (prod[31]) ? -32'sd16384 : 32'sd16384;
    wire signed [31:0] prod_rnd = prod + bias;

    wire signed [15:0] y_am = prod_rnd[30:15]; // >>15

    // Enable mux via ternary operator
    assign o_y = (i_enable) ? y_am : i_x;

endmodule

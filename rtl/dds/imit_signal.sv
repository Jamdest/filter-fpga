`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
// 
// Create Date: 14.02.2026 19:41:02
// Design Name:
// Module Name: imit_signal
// Project Name: 
// Target Devices: 
// Tool Versions: vivado 2024.1
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module imit_signal#(
    parameter START_FREQ    = 32'h0000,
    parameter STOP_FREQ     = 32'hFFFF,
    parameter STEP          = 32'h100,
    
    parameter MOD           = "linear"
)(
    input wire clk,
    input wire rst,
    input wire i_btn_start,
    
    output wire [15:0]  o_data
    );
    
    
    
    dds_compiler_0 dds_0(
        .aclk(clk),
        .aresetn(!rst),
        .s_axis_config_tdata(),
        .s_axis_config_tvalid()
    );
    
endmodule

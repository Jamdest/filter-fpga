`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////



module top(
    input wire clk,
    input wire rst,
    input wire i_btn_start,
    
    output wire [5:0] o_leds
    );
    
    
    wire clk_wiz_out;
    wire clk_100m;
    wire clk_wiz_locked;
    
    assign clk_100m = (locked)? clk_wiz_out: 1'b0; // sync clk for all logic
    
    clk_wiz_50 clk_50_to_100(
        .clk_in1(clk),
        .reset(rst),
        .clk_out1(clk_wiz_out),
        .locked(clk_wiz_locked)
    );
endmodule

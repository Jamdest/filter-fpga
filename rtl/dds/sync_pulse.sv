`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: sync_pulse
// Purpose:
//   - Safely bring an asynchronous input into the clk domain (2-FF synchronizer)
//   - Generate a single-clock pulse on rising edge (and optionally falling)
// Notes:
//   - This does NOT debounce a mechanical button. It only removes metastability.
//   - For button bounce you may add a debounce filter later if needed.
//------------------------------------------------------------------------------
module sync_pulse (
    input  wire clk,
    input  wire rst,          // active-high synchronous reset
    input  wire i_async,      // asynchronous input (e.g. push button)
    output wire o_sync,       // synchronized level in clk domain
    output wire o_rise_pulse, // 1 clk pulse on rising edge of o_sync
    output wire o_fall_pulse  // 1 clk pulse on falling edge of o_sync
);

    reg ff1, ff2;

    always @(posedge clk) begin
        if (rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= i_async;
            ff2 <= ff1;
        end
    end

    // Synchronized level
    assign o_sync = ff2;

    // Edge pulses (combinational from two synchronized samples)
    assign o_rise_pulse =  ff1 & ~ff2;
    assign o_fall_pulse = ~ff1 &  ff2;

endmodule

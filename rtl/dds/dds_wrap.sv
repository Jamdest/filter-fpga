`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: dds_wrapper
// Purpose:
//   - Wrap Vivado DDS Compiler IP with a clean RTL interface
//   - Build s_axis_config_tdata as {pinc, poff}
// Notes:
//   - Assumes the DDS IP was configured to use s_axis_config (no tready)
//   - Output widths must match your DDS IP configuration
//------------------------------------------------------------------------------
module dds_wrapper (
    input  wire        clk,
    input  wire        rst,         // active-high synchronous reset
    input  wire [15:0] i_pinc,
    input  wire [15:0] i_poff,
    input  wire        i_cfg_valid, // 1 clk strobe when config should be captured
    output wire [15:0] o_data,
    output wire [15:0] o_phase
);

    wire [31:0] cfg_tdata = {i_pinc, i_poff};
    wire        aresetn   = ~rst;

    // DDS IP instance (port names must match your generated IP)
    dds_compiler_0 dds_0 (
        .aclk                 (clk),
        .aresetn              (aresetn),
        .s_axis_config_tdata  (cfg_tdata),
        .s_axis_config_tvalid (i_cfg_valid),
        .m_axis_data_tdata    (o_data),
        .m_axis_phase_tdata   (o_phase)
    );

endmodule

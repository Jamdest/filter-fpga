`timescale 1ns / 1ps

//------------------------------------------------------------------------------
module dds_wrapper (
    input  wire clk,
    input  wire rst,
    input  wire [15:0] i_pinc,
    input  wire [15:0] i_poff,
    input  wire i_cfg_valid,
    output wire [31:0] o_data,
    output wire [15:0] o_phase
);
    wire [31:0] cfg_tdata;
    wire aresetn;

    // Сборка шины конфигурации
    assign cfg_tdata = {i_pinc, i_poff};
    assign aresetn = ~rst;

    // Инстанс стандартного IP-ядра DDS
    dds_compiler_0 dds_0 (
        .aclk(clk),
        .aresetn(aresetn),
        .s_axis_config_tdata(cfg_tdata),
        .s_axis_config_tvalid(i_cfg_valid),
        .m_axis_data_tdata(o_data),
        .m_axis_phase_tdata(o_phase)
    );

endmodule
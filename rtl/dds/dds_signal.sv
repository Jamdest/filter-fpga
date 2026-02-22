`timescale 1ns / 1ps

//------------------------------------------------------------------------------
module dds_signal#(
    parameter START_FREQ    = 32'h147A_E147,
    parameter STOP_FREQ     = 32'h3333_3333,
    parameter STEP_FREQ     = 32'h0000_2710,
    
    parameter MODULATION    = "LFM",
    
    localparam P_NUM_STEP = (START_FREQ - STOP_FREQ)/STEP_FREQ
) (
    input  wire clk,
    input  wire rst,
    input  wire i_btn_start,
    output wire [13:0] o_sine,
    output wire [13:0] o_cosine,
    output wire [15:0] o_phase
);

    //dds compiler wires
    wire [63:0] cfg_tdata;  // pinc + poff
    wire        aresetn;    // rst 
    wire [15:0] pinc; 
    wire [15:0] poff; 
    wire [31:0] data_dds_out;    // cosine + sine output
    
    // FSM
    reg [$clog2(P_NUM_STEP)-1:0]    cnt_step;
    
    typedef enum reg [1:0] {
        ST_IDLE  = 2'b00,
        ST_START = 2'b01,
        ST_SWEEP = 2'b10,
        ST_DONE  = 2'b11
    } t_state;
    
    t_state  state;
    
    
    reg [31:0] pinc_curr;
    reg        cfg_valid;

    assign cfg_tdata = {32'h0000, pinc_curr};
    assign aresetn = ~rst;
    assign o_sine = data_dds_out[13:0];
    assign o_cosine = data_dds_out[29:16];
    // Инстанс стандартного IP-ядра DDS
    dds_compiler_0 dds_0 (
        .aclk(clk),
        .aresetn(aresetn),
        .s_axis_config_tdata(cfg_tdata),
        .s_axis_config_tvalid(cfg_valid),
        .m_axis_data_tdata(data_dds_out),
        .m_axis_phase_tdata(o_phase)
    );
    
    
    
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= ST_IDLE;
            pinc_curr <= START_FREQ;
            cfg_valid <= 1'b0;
        end else begin
            case (state)
                // Ожидание команды на старт
                ST_IDLE: begin
                    cfg_valid <= 1'b0;
                    if (i_btn_start) begin
                        state     <= ST_START;
                        pinc_curr <= START_FREQ;
                    end
                end

                // Инициализация первой частоты
                ST_START: begin
                    cfg_valid <= 1'b1;
                    state     <= ST_SWEEP;
                end

                // Процесс изменения частоты (Sweep)
                ST_SWEEP: begin
                    if (pinc_curr < STOP_FREQ) begin
                        pinc_curr <= pinc_curr + STEP_FREQ;
                        cfg_valid <= 1'b1;
                    end else begin
                        cfg_valid <= 1'b0;
                        state     <= ST_DONE;
                    end
                end

                // Конец пачки, возврат в IDLE
                ST_DONE: begin
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
        
        
        
 endmodule
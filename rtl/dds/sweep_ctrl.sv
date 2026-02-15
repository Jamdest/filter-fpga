`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: sweep_ctrl
// Purpose:
//   - Produce DDS phase increment word (pinc) updates over time
//   - On start pulse: load START_FREQ and assert cfg_valid for 1 clk
//   - While running: every DWELL_CYCLES clocks update pinc by STEP
//   - If MODE == "linear": wrap to START_FREQ when exceeding STOP_FREQ
//   - If MODE != "linear": hold pinc constant (START_FREQ) (no sweep)
// Outputs:
//   - o_pinc      : current phase increment word (FTW) to be sent to DDS
//   - o_poff      : phase offset word (kept at 0 here)
//   - o_cfg_valid : 1 clk pulse whenever configuration should be resent to DDS
//   - o_running   : high after start pulse (continuous generator enable)
//------------------------------------------------------------------------------
module sweep_ctrl #(
    parameter [31:0] START_FREQ    = 32'h0000,
    parameter [31:0] STOP_FREQ     = 32'hFFFF,
    parameter [31:0] STEP          = 32'h0100,
    parameter integer DWELL_CYCLES = 50_000,
    parameter string MOD           = "linear"
)(
    input  wire        clk,
    input  wire        rst,          // active-high synchronous reset
    input  wire        i_start_pulse, // 1 clk pulse (already synchronized)
    output wire        o_running,
    output wire [15:0] o_pinc,
    output wire [15:0] o_poff,
    output wire        o_cfg_valid
);

    localparam integer P_DWELL = (DWELL_CYCLES < 1) ? 1 : DWELL_CYCLES;
    localparam bit MODE_LINEAR = (MOD == "linear");

    wire [15:0] start_val = START_FREQ[15:0];
    wire [15:0] stop_val  = STOP_FREQ[15:0];
    wire [15:0] step_val  = STEP[15:0];

    reg        running;
    reg [15:0] pinc_reg;
    reg [31:0] dwell_cnt;
    reg        cfg_valid_reg;

    // Compute pinc + step with extra bit to detect overflow above stop
    wire [16:0] pinc_plus_step_ext = {1'b0, pinc_reg} + {1'b0, step_val};

    // Next pinc for linear sweep with wrap:
    //   if (pinc + step > stop) -> start else -> pinc + step
    wire [15:0] next_pinc_linear =
        (pinc_plus_step_ext > {1'b0, stop_val}) ? start_val : pinc_plus_step_ext[15:0];

    // Final next pinc depending on mode
    wire [15:0] next_pinc =
        (MODE_LINEAR) ? next_pinc_linear : pinc_reg;

    always @(posedge clk) begin
        if (rst) begin
            running       <= 1'b0;
            pinc_reg      <= start_val;
            dwell_cnt     <= 32'd0;
            cfg_valid_reg <= 1'b0;
        end else begin
            // Default: cfg_valid is a one-clock strobe
            cfg_valid_reg <= 1'b0;

            // Start / restart
            if (i_start_pulse) begin
                running       <= 1'b1;
                pinc_reg      <= start_val;
                dwell_cnt     <= 32'd0;
                cfg_valid_reg <= 1'b1; // push START_FREQ into DDS immediately
            end else if (running) begin
                // Dwell counter
                if (dwell_cnt == (P_DWELL - 1)) begin
                    dwell_cnt     <= 32'd0;
                    pinc_reg      <= next_pinc;
                    cfg_valid_reg <= 1'b1; // resend configuration to DDS
                end else begin
                    dwell_cnt <= dwell_cnt + 32'd1;
                end
            end
        end
    end

    // Phase offset is constant 0 in this generator
    assign o_poff      = 16'd0;
    assign o_pinc      = pinc_reg;
    assign o_cfg_valid = cfg_valid_reg;
    assign o_running   = running;

endmodule

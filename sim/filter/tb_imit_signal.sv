`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Testbench: tb_imit_signal
// - Generates 50 MHz clock
// - Applies reset
// - Pulses i_btn_start (async-like)
// - Captures output samples when o_valid_data is high
// - Optionally uses a behavioral DDS stub (no Vivado IP required)
// -----------------------------------------------------------------------------
module tb_imit_signal;

    // ----------------------------
    // Clock / reset
    // ----------------------------
    reg clk;
    reg rst;

    // "Button" input (async)
    reg i_btn_start;

    // DUT outputs
    wire [15:0] o_data;
    wire [15:0] o_phase;
    wire        o_valid_data;
    wire        o_valid_phase;

    // 50 MHz -> 20 ns period
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ----------------------------
    // Instantiate DUT
    // ----------------------------
    // Adjust parameters as you like for simulation speed/visibility.
    // DWELL_CYCLES small -> sweep changes fast in sim.
    imit_signal #(
        .START_FREQ    (32'h0100),
        .STOP_FREQ     (32'h2000),
        .STEP          (32'h0100),
        .DWELL_CYCLES  (2000),           // 2000 cycles @50MHz = 40 us per step
        .MOD           ("linear"),
        .MODULATION    ("am"),
        .AM_STEP       (32'd85899),      // ~1 kHz envelope @50MHz (for long runs)
        .AM_DEPTH_Q15  (16'd16384)       // 50% depth
    ) dut (
        .clk          (clk),
        .rst          (rst),
        .i_btn_start  (i_btn_start),
        .o_data       (o_data),
        .o_phase      (o_phase),
        .o_valid_data (o_valid_data),
        .o_valid_phase(o_valid_phase)
    );

    // ----------------------------
    // Helpers
    // ----------------------------
    task pulse_button;
        input integer pulse_ns;
        begin
            // generate a short async pulse not aligned to clk edges
            #(pulse_ns/2);
            i_btn_start = 1'b1;
            #pulse_ns;
            i_btn_start = 1'b0;
        end
    endtask

    integer f;
    integer sample_cnt;

    initial begin
        // Init
        rst         = 1'b1;
        i_btn_start = 1'b0;
        sample_cnt  = 0;

        // Optional waveform dump (works in many simulators; if not, just remove)
        `ifndef NO_DUMP
            $dumpfile("tb_imit_signal.vcd");
            $dumpvars(0, tb_imit_signal);
        `endif

        // Open CSV for quick plotting
        f = $fopen("imit_signal_samples.csv", "w");
        $fwrite(f, "time_ns,valid,data_u16,phase_u16\n");

        // Hold reset for a few cycles
        repeat (10) @(posedge clk);
        rst = 1'b0;

        // Wait a bit then "press" start
        #123;                 // de-align from clock intentionally
        pulse_button(80);     // 80 ns button pulse

        // Run simulation for some time (adjust as needed)
        // 2 ms at 50MHz is 100k cycles -> enough to see sweep + AM
        #2_000_000;

        $display("TB finished. Captured %0d samples.", sample_cnt);
        $fclose(f);
        $finish;
    end

    // Capture samples when valid
    always @(posedge clk) begin
        if (!rst && o_valid_data) begin
            sample_cnt <= sample_cnt + 1;
            $fwrite(f, "%0t,%0d,%0d,%0d\n", $time, o_valid_data, o_data, o_phase);

            // Print occasionally
            if ((sample_cnt % 5000) == 0) begin
                $display("[%0t ns] data=%0d phase=%0d", $time, o_data, o_phase);
            end
        end
    end

endmodule


// -----------------------------------------------------------------------------
// Optional behavioral DDS stub
// Use this if you don't want to simulate the real Vivado DDS IP.
// Enable by compiling with +define+TB_USE_DDS_STUB (or set in simulator options).
// -----------------------------------------------------------------------------
`ifdef TB_USE_DDS_STUB
module dds_compiler_0(
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [31:0] s_axis_config_tdata,   // {pinc, poff}
    input  wire        s_axis_config_tvalid,
    output reg  [15:0] m_axis_data_tdata,
    output reg  [15:0] m_axis_phase_tdata
);
    // Simple phase accumulator model:
    // phase += pinc; output = sin(phase + poff)
    reg  [15:0] pinc;
    reg  [15:0] poff;
    reg  [31:0] phase_acc; // extra bits for smoother sin argument
    real ang;
    real s;

    always @(posedge aclk) begin
        if (!aresetn) begin
            pinc <= 16'd0;
            poff <= 16'd0;
            phase_acc <= 32'd0;
            m_axis_phase_tdata <= 16'd0;
            m_axis_data_tdata  <= 16'd0;
        end else begin
            if (s_axis_config_tvalid) begin
                pinc <= s_axis_config_tdata[31:16];
                poff <= s_axis_config_tdata[15:0];
            end

            phase_acc <= phase_acc + {pinc, 16'd0}; // scale to 32-bit phase
            m_axis_phase_tdata <= phase_acc[31:16] + poff;

            // Convert phase to radians and generate sine
            ang = 6.283185307179586 * ( (m_axis_phase_tdata) / 65536.0 );
            s   = $sin(ang);

            // Map [-1..1] to signed 16-bit
            // (Use 32767 amplitude to avoid overflow)
            m_axis_data_tdata <= $rtoi( s * 32767.0 );
        end
    end
endmodule
`endif

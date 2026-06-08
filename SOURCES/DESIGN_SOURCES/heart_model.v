`timescale 1ns/1ps

module heart_model (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [2:0]  mode,           // 0: Normal, 1: Brady, 2: Tachy, 3: AV Block, 4: AFib
    input  wire        a_pace,         // Atrial pacing signal
    input  wire        v_pace,         // Ventricular pacing signal
    output wire        a_sense_raw,
    output wire        v_sense_raw
);

    parameter CLK_FREQ_HZ = 1000;      // Default 1 kHz (1 ms period)

    // Calculate cycle thresholds
    localparam CYCLES_800MS  = (800 * CLK_FREQ_HZ) / 1000;
    localparam CYCLES_1500MS = (1500 * CLK_FREQ_HZ) / 1000;
    localparam CYCLES_400MS  = (400 * CLK_FREQ_HZ) / 1000;
    localparam CYCLES_150MS  = (150 * CLK_FREQ_HZ) / 1000;
    localparam CYCLES_100MS  = (100 * CLK_FREQ_HZ) / 1000;

    // Mode Definitions
    localparam MODE_NORMAL = 3'd0;
    localparam MODE_BRADY  = 3'd1;
    localparam MODE_TACHY  = 3'd2;
    localparam MODE_AV_BLK = 3'd3;
    localparam MODE_AFIB   = 3'd4;

    // Counters for Atrial and Ventricular periods
    reg [31:0] a_counter;

    // Target intervals
    reg [31:0] a_interval;
    reg [31:0] v_delay; // delay from A to V

    // 16-bit LFSR for pseudo-random interval generation (AFib mode)
    reg [15:0] lfsr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1; // non-zero seed
        end else if (enable) begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};
        end
    end

    // Determine target intervals based on mode
    always @(*) begin
        case (mode)
            MODE_NORMAL: begin
                a_interval = CYCLES_800MS;
                v_delay    = CYCLES_150MS;
            end
            MODE_BRADY: begin
                a_interval = CYCLES_1500MS;
                v_delay    = CYCLES_150MS;
            end
            MODE_TACHY: begin
                a_interval = CYCLES_400MS;
                v_delay    = CYCLES_100MS;
            end
            MODE_AV_BLK: begin
                a_interval = CYCLES_800MS;
                v_delay    = 0;
            end
            MODE_AFIB: begin
                a_interval = ((300 + (lfsr[7:0] * 400) / 255) * CLK_FREQ_HZ) / 1000;
                v_delay    = ((80 + (lfsr[15:8] * 170) / 255) * CLK_FREQ_HZ) / 1000;
            end
            default: begin
                a_interval = CYCLES_800MS;
                v_delay    = CYCLES_150MS;
            end
        endcase
    end

    // Atrial Sense Signal Generation (Internal register)
    reg a_sense_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_counter   <= 0;
            a_sense_reg <= 1'b0;
        end else if (enable) begin
            if (a_pace) begin
                a_counter   <= 0;
                a_sense_reg <= 1'b0;
            end else if (a_counter >= a_interval - 1) begin
                a_counter   <= 0;
                a_sense_reg <= 1'b1;
            end else begin
                a_counter   <= a_counter + 1;
                a_sense_reg <= 1'b0;
            end
        end else begin
            a_counter   <= 0;
            a_sense_reg <= 1'b0;
        end
    end

    // Ventricular Sense Signal Generation (Internal register)
    reg v_trigger_pending;
    reg [31:0] v_delay_counter;
    reg v_sense_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_delay_counter   <= 0;
            v_trigger_pending <= 0;
            v_sense_reg       <= 1'b0;
        end else if (enable) begin
            if (v_pace) begin
                v_trigger_pending <= 1'b0;
                v_delay_counter   <= 0;
                v_sense_reg       <= 1'b0;
            end else begin
                // Detect a_sense_raw (active atrial contraction) to start delay
                if (a_sense_raw && (mode != MODE_AV_BLK)) begin
                    v_trigger_pending <= 1'b1;
                    v_delay_counter   <= 0;
                end

                if (v_trigger_pending) begin
                    if (v_delay_counter >= v_delay - 1) begin
                        v_trigger_pending <= 1'b0;
                        v_sense_reg       <= 1'b1;
                    end else begin
                        v_delay_counter   <= v_delay_counter + 1;
                        v_sense_reg       <= 1'b0;
                    end
                end else begin
                    v_sense_reg <= 1'b0;
                end
            end
        end else begin
            v_delay_counter   <= 0;
            v_trigger_pending <= 0;
            v_sense_reg       <= 1'b0;
        end
    end

    // Combinational override: inhibit sense output if pacemaker is pacing in this cycle
    assign a_sense_raw = a_sense_reg && !a_pace;
    assign v_sense_raw = v_sense_reg && !v_pace;

endmodule

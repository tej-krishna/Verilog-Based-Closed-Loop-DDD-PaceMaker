`timescale 1ns/1ps

module rhythm_classifier (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        a_sense,
    input  wire        v_sense,
    output reg  [2:0]  rhythm_type
);

    parameter CLK_FREQ_HZ = 1000; // Default 1 kHz (1 ms period)

    // Configuration parameters
    localparam THRESHOLD_BRADY = (1000 * CLK_FREQ_HZ) / 1000; // > 1000ms (60 BPM)
    localparam THRESHOLD_TACHY = (500 * CLK_FREQ_HZ) / 1000;  // < 500ms (120 BPM)
    localparam THRESHOLD_AV    = (300 * CLK_FREQ_HZ) / 1000;  // AV delay > 300ms

    // Rhythm Types
    localparam RHYTHM_NORMAL   = 3'b000;
    localparam RHYTHM_BRADY    = 3'b001;
    localparam RHYTHM_TACHY    = 3'b010;
    localparam RHYTHM_AV_BLOCK = 3'b011;
    localparam RHYTHM_AFIB     = 3'b100;

    // Counters for measuring intervals
    reg [31:0] rr_counter; // Ventricular-to-Ventricular (RR) counter
    reg [31:0] pp_counter; // Atrial-to-Atrial (PP) counter
    reg [31:0] av_counter; // Atrial-to-Ventricular (AV) counter

    // Stored intervals
    reg [31:0] rr_interval;
    reg [31:0] prev_rr_interval;
    reg [31:0] pp_interval;
    reg [31:0] av_interval;

    reg av_pending;
    reg av_timeout_occurred;

    // Measure PP (Atrial-to-Atrial) Interval
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pp_counter  <= 0;
            pp_interval <= 0;
        end else begin
            if (a_sense) begin
                pp_interval <= pp_counter + 1;
                pp_counter  <= 0;
            end else begin
                pp_counter <= pp_counter + 1;
            end
        end
    end

    // Measure RR (Ventricular-to-Ventricular) Interval
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_counter      <= 0;
            rr_interval     <= 0;
            prev_rr_interval <= 0;
        end else begin
            if (v_sense) begin
                prev_rr_interval <= rr_interval;
                rr_interval      <= rr_counter + 1;
                rr_counter       <= 0;
            end else begin
                rr_counter <= rr_counter + 1;
            end
        end
    end

    // Measure AV (Atrial-to-Ventricular) Delay and Detect AV Block Timeout
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            av_counter          <= 0;
            av_interval         <= 0;
            av_pending          <= 0;
            av_timeout_occurred <= 0;
        end else begin
            if (a_sense) begin
                av_pending          <= 1'b1;
                av_counter          <= 0;
                av_timeout_occurred <= 0;
            end else if (v_sense && av_pending) begin
                av_interval         <= av_counter + 1;
                av_pending          <= 1'b0;
                av_timeout_occurred <= 0;
            end else if (av_pending) begin
                if (av_counter >= THRESHOLD_AV) begin
                    av_timeout_occurred <= 1'b1;
                    av_pending          <= 1'b0; // stop counting, timeout occurred
                end else begin
                    av_counter <= av_counter + 1;
                end
            end
        end
    end

    // AFib Detection Logic: Irregular RR intervals
    // If the difference between current RR and previous RR is > 20% of previous RR for multiple consecutive beats.
    reg [2:0] irregularity_count;
    wire [31:0] rr_diff = (rr_interval > prev_rr_interval) ? (rr_interval - prev_rr_interval) : (prev_rr_interval - rr_interval);
    wire is_irregular = (prev_rr_interval > 0) && (rr_diff > (prev_rr_interval / 5)); // > 20% variation

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irregularity_count <= 0;
        end else if (v_sense) begin
            if (is_irregular) begin
                if (irregularity_count < 3)
                    irregularity_count <= irregularity_count + 1;
            end else begin
                if (irregularity_count > 0)
                    irregularity_count <= irregularity_count - 1;
            end
        end
    end

    // Classification Decision Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rhythm_type <= RHYTHM_NORMAL;
        end else begin
            if (av_timeout_occurred) begin
                rhythm_type <= RHYTHM_AV_BLOCK;
            end else if (irregularity_count >= 2) begin
                rhythm_type <= RHYTHM_AFIB;
            end else if (rr_interval > THRESHOLD_BRADY) begin
                rhythm_type <= RHYTHM_BRADY;
            end else if (rr_interval > 0 && rr_interval < THRESHOLD_TACHY) begin
                rhythm_type <= RHYTHM_TACHY;
            end else begin
                rhythm_type <= RHYTHM_NORMAL;
            end
        end
    end

endmodule

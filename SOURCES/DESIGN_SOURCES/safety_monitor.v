`timescale 1ns/1ps

module safety_monitor (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        a_pace,
    input  wire        v_pace,
    input  wire        a_sense,
    input  wire        v_sense,
    input  wire [2:0]  state,
    output reg         fault_flag
);

    parameter CLK_FREQ_HZ = 1000; // Default 1 kHz (1 ms period)

    localparam CYCLES_350MS = (350 * CLK_FREQ_HZ) / 1000;
    localparam STATE_REFRACTORY = 3'd3;
    localparam STATE_EMERGENCY  = 3'd4;

    // Internal state for tracking pacing and refractory transition
    reg a_pace_prev;
    reg v_pace_prev;
    reg [31:0] av_watchdog_counter;
    reg av_watchdog_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fault_flag          <= 1'b0;
            a_pace_prev         <= 1'b0;
            v_pace_prev         <= 1'b0;
            av_watchdog_counter <= 0;
            av_watchdog_active  <= 1'b0;
        end else begin
            // Latched prev pacing inputs
            a_pace_prev <= a_pace;
            v_pace_prev <= v_pace;

            // --- Assertion 1: Simultaneous A_PACE and V_PACE must never occur ---
            if (a_pace && v_pace) begin
                fault_flag <= 1'b1;
            end

            // --- Assertion 2: Pacing during sensing must never occur ---
            if ((a_pace && a_sense) || (v_pace && v_sense)) begin
                fault_flag <= 1'b1;
            end

            // --- Assertion 3: Refractory or Emergency state must immediately follow ventricular pacing ---
            if (v_pace_prev && (state != STATE_REFRACTORY) && (state != STATE_EMERGENCY)) begin
                // In the cycle immediately after ventricular pacing, FSM must be in REFRACTORY or EMERGENCY state
                fault_flag <= 1'b1;
            end

            // --- Assertion 4: AV delay/watchdog timeout must never exceed limit (350ms) ---
            if (a_pace || a_sense) begin
                av_watchdog_active  <= 1'b1;
                av_watchdog_counter <= 0;
            end else if (v_pace || v_sense) begin
                av_watchdog_active  <= 1'b0;
                av_watchdog_counter <= 0;
            end else if (av_watchdog_active) begin
                if (av_watchdog_counter >= CYCLES_350MS) begin
                    fault_flag <= 1'b1; // AV watchdog timeout violated
                end else begin
                    av_watchdog_counter <= av_watchdog_counter + 1;
                end
            end
        end
    end

endmodule

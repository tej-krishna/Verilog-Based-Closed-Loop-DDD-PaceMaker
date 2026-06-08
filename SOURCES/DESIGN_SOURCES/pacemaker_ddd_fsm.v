`timescale 1ns/1ps

module pacemaker_ddd_fsm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        a_sense,
    input  wire        v_sense,
    input  wire [31:0] av_delay_cycles,
    input  wire        emergency_flag,
    output reg         a_pace,
    output reg         v_pace,
    output reg  [2:0]  state
);

    parameter CLK_FREQ_HZ = 1000; // Default 1 kHz (1 ms period)

    // FSM States
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_ALERT_A    = 3'd1; // Wait for Atrial event (AEI)
    localparam STATE_ALERT_V    = 3'd2; // Wait for Ventricular event (AVD)
    localparam STATE_REFRACTORY = 3'd3; // Refractory period
    localparam STATE_EMERGENCY  = 3'd4; // Emergency state

    // Time constants
    localparam CYCLES_1000MS = (1000 * CLK_FREQ_HZ) / 1000; // Lower Rate Limit (60 BPM)
    localparam CYCLES_250MS  = (250 * CLK_FREQ_HZ) / 1000;  // Refractory Period (PVARP/VRP)
    localparam CYCLES_666MS  = (666 * CLK_FREQ_HZ) / 1000;  // Emergency pacing (90 BPM)
    localparam CYCLES_150MS  = (150 * CLK_FREQ_HZ) / 1000;  // Emergency AV Delay

    // Timers
    reg [31:0] aei_timer;
    reg [31:0] avd_timer;
    reg [31:0] ref_timer;
    reg [31:0] emergency_timer;

    // Derived Atrial Escape Interval (AEI) = Lower Rate Limit (1000ms) - AV Delay
    wire [31:0] aei_limit = (CYCLES_1000MS > av_delay_cycles) ? (CYCLES_1000MS - av_delay_cycles) : 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= STATE_IDLE;
            a_pace           <= 1'b0;
            v_pace           <= 1'b0;
            aei_timer        <= 0;
            avd_timer        <= 0;
            ref_timer        <= 0;
            emergency_timer  <= 0;
        end else begin
            // Default outputs
            a_pace <= 1'b0;
            v_pace <= 1'b0;

            // Global Emergency Override
            if (emergency_flag && state != STATE_EMERGENCY) begin
                state           <= STATE_EMERGENCY;
                emergency_timer <= 0;
            end else begin
                case (state)
                    STATE_IDLE: begin
                        state     <= STATE_ALERT_A;
                        aei_timer <= 0;
                    end

                    STATE_ALERT_A: begin
                        // Wait for atrial sense or timeout to pace
                        if (a_sense) begin
                            state     <= STATE_ALERT_V;
                            avd_timer <= 0;
                        end else if (aei_timer >= aei_limit - 1) begin
                            a_pace    <= 1'b1; // Trigger Atrial Pace
                            state     <= STATE_ALERT_V;
                            avd_timer <= 0;
                        end else begin
                            aei_timer <= aei_timer + 1;
                        end
                    end

                    STATE_ALERT_V: begin
                        // Wait for ventricular sense or timeout to pace
                        if (v_sense) begin
                            state     <= STATE_REFRACTORY;
                            ref_timer <= 0;
                        end else if (avd_timer >= av_delay_cycles - 1) begin
                            v_pace    <= 1'b1; // Trigger Ventricular Pace
                            state     <= STATE_REFRACTORY;
                            ref_timer <= 0;
                        end else begin
                            avd_timer <= avd_timer + 1;
                        end
                    end

                    STATE_REFRACTORY: begin
                        // Ignore all sense inputs during refractory period
                        if (ref_timer >= CYCLES_250MS - 1) begin
                            state     <= STATE_ALERT_A;
                            aei_timer <= 0;
                        end else begin
                            ref_timer <= ref_timer + 1;
                        end
                    end

                    STATE_EMERGENCY: begin
                        // Pace atrium and ventricle at a safe fixed rate (90 BPM)
                        // A-pace, wait 150ms, V-pace, wait (666-150)ms refractory/alert, repeat
                        if (!emergency_flag) begin
                            state     <= STATE_ALERT_A;
                            aei_timer <= 0;
                        end else begin
                            if (emergency_timer == 0) begin
                                a_pace <= 1'b1; // Atrial pace at start of cycle
                            end else if (emergency_timer == CYCLES_150MS) begin
                                v_pace <= 1'b1; // Ventricular pace after 150ms
                            end

                            if (emergency_timer >= CYCLES_666MS - 1) begin
                                emergency_timer <= 0;
                            end else begin
                                emergency_timer <= emergency_timer + 1;
                            end
                        end
                    end

                    default: begin
                        state <= STATE_IDLE;
                    end
                endcase
            end
        end
    end

endmodule

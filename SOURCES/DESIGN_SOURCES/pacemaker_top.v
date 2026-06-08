`timescale 1ns/1ps

module pacemaker_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable_heart_model,
    input  wire [2:0]  heart_mode,
    input  wire        emergency_btn,
    output wire        a_pace,
    output wire        v_pace,
    output wire        a_sense,
    output wire        v_sense,
    output wire [2:0]  rhythm_type,
    output wire [15:0] bpm,
    output wire        fault_flag,
    output wire [2:0]  state
);

    parameter CLK_FREQ_HZ = 1000; // 1 kHz default clock

    wire a_event = a_sense | a_pace; // Atrial event is intrinsic sense or paced
    wire v_event = v_sense | v_pace; // Ventricular event is intrinsic sense or paced
    wire [31:0] av_delay_cycles;

    // 1. Instantiate Heart Model Emulator
    heart_model #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_heart_model (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_heart_model),
        .mode(heart_mode),
        .a_pace(a_pace),
        .v_pace(v_pace),
        .a_sense_raw(a_sense),
        .v_sense_raw(v_sense)
    );

    // 2. Instantiate BPM Calculator
    bpm_calculator #(
        .Fs(CLK_FREQ_HZ)
    ) u_bpm_calculator (
        .clk(clk),
        .rst_n(rst_n),
        .heartbeat_detected(v_event),
        .bpm(bpm),
        .classification()
    );

    // 3. Instantiate Rhythm Classifier
    rhythm_classifier #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_rhythm_classifier (
        .clk(clk),
        .rst_n(rst_n),
        .a_sense(a_event),
        .v_sense(v_event),
        .rhythm_type(rhythm_type)
    );

    // 4. Instantiate Adaptive AV Delay
    adaptive_av_delay #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_adaptive_av_delay (
        .clk(clk),
        .rst_n(rst_n),
        .bpm(bpm),
        .av_delay_cycles(av_delay_cycles)
    );

    // 5. Instantiate DDD Pacemaker FSM Controller
    pacemaker_ddd_fsm #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_pacemaker_ddd_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .a_sense(a_sense),
        .v_sense(v_sense),
        .av_delay_cycles(av_delay_cycles),
        .emergency_flag(emergency_btn),
        .a_pace(a_pace),
        .v_pace(v_pace),
        .state(state)
    );

    // 6. Instantiate Safety Monitor
    safety_monitor #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_safety_monitor (
        .clk(clk),
        .rst_n(rst_n),
        .a_pace(a_pace),
        .v_pace(v_pace),
        .a_sense(a_sense),
        .v_sense(v_sense),
        .state(state),
        .fault_flag(fault_flag)
    );

endmodule

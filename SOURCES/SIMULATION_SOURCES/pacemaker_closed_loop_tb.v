`timescale 1ns/1ps

module pacemaker_closed_loop_tb;

    reg clk;
    reg rst_n;
    reg enable_heart_model;
    reg [2:0] heart_mode;
    reg emergency_btn;

    wire a_pace;
    wire v_pace;
    wire a_sense;
    wire v_sense;
    wire [2:0] rhythm_type;
    wire [15:0] bpm;
    wire fault_flag;
    wire [2:0] state;

    // Instantiate Top Module
    pacemaker_top #(
        .CLK_FREQ_HZ(1000) // 1 kHz clock
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable_heart_model(enable_heart_model),
        .heart_mode(heart_mode),
        .emergency_btn(emergency_btn),
        .a_pace(a_pace),
        .v_pace(v_pace),
        .a_sense(a_sense),
        .v_sense(v_sense),
        .rhythm_type(rhythm_type),
        .bpm(bpm),
        .fault_flag(fault_flag),
        .state(state)
    );

    // Clock generation: 1 ms period (1 kHz clock)
    always #500000 clk = ~clk;

    // Monitor changes
    always @(posedge clk) begin
        if (a_pace)  $display("[TIME: %0d ms] >>> PACEMAKER TRIGGERED: A_PACE", $time/1000000);
        if (v_pace)  $display("[TIME: %0d ms] >>> PACEMAKER TRIGGERED: V_PACE", $time/1000000);
        if (a_sense) $display("[TIME: %0d ms] HEART EVENT: A_SENSE (Intrinsic Atrial)", $time/1000000);
        if (v_sense) $display("[TIME: %0d ms] HEART EVENT: V_SENSE (Intrinsic Ventricular)", $time/1000000);
    end

    // Monitor rhythm classification and BPM
    reg [2:0] prev_rhythm;
    always @(posedge clk) begin
        if (rhythm_type != prev_rhythm) begin
            $display("[TIME: %0d ms] Rhythm Classifier Changed: %0d -> %0d (BPM: %0d)", 
                     $time/1000000, prev_rhythm, rhythm_type, bpm);
            prev_rhythm <= rhythm_type;
        end
    end

    // Watchdog for safety monitor fault
    always @(posedge clk) begin
        if (fault_flag) begin
            $display("[TIME: %0d ms] !!! SAFETY VIOLATION DETECTED: FAULT_FLAG ASSERTED !!!", $time/1000000);
        end
    end

    initial begin
        clk = 0;
        rst_n = 0;
        enable_heart_model = 0;
        heart_mode = 0;
        emergency_btn = 0;
        prev_rhythm = 0;

        $display("==================================================");
        $display("Starting Pacemaker Closed-Loop Integration Testbench");
        $display("==================================================");

        #2000000; // 2 ms reset
        rst_n = 1;
        enable_heart_model = 1;

        // 1. Normal Heart Mode
        $display("\n--- [MODE 0] NORMAL HEART (Expect 75 BPM, 150ms AV delay, Pacemaker Inactive) ---");
        heart_mode = 3'd0;
        repeat(5000) #1000000; // 5000 ms

        // 2. Bradycardia Heart Mode
        $display("\n--- [MODE 1] BRADYCARDIA (Expect 40 Intrinsic BPM, Pacemaker should pace A at LRL 60 BPM and V after 180ms) ---");
        heart_mode = 3'd1;
        repeat(8000) #1000000; // 8000 ms

        // 3. Tachycardia Heart Mode
        $display("\n--- [MODE 2] TACHYCARDIA (Expect 150 Intrinsic BPM, Pacemaker should inhibit completely) ---");
        heart_mode = 3'd2;
        repeat(4000) #1000000; // 4000 ms

        // 4. AV Block Heart Mode
        $display("\n--- [MODE 3] AV_BLOCK (Expect Atrial beats but Ventricle missing; Pacemaker should pace Ventricle on AV timeout) ---");
        heart_mode = 3'd3;
        repeat(6000) #1000000; // 6000 ms

        // 5. AFib Heart Mode
        $display("\n--- [MODE 4] AFIB (Expect irregular rhythms; Pacemaker should inhibit on fast/normal beats, pace on slow pauses) ---");
        heart_mode = 3'd4;
        repeat(8000) #1000000; // 8000 ms

        // 6. Emergency Button
        $display("\n--- Testing Emergency Mode (Expect constant high pacing 90 BPM) ---");
        emergency_btn = 1;
        repeat(3000) #1000000; // 3000 ms
        emergency_btn = 0;
        repeat(2000) #1000000; // 2000 ms

        // 7. Inject Fault (Force safety violation)
        $display("\n--- Injecting Safety Fault (Simultaneous A_PACE & V_PACE) ---");
        // We will force a timing conflict to test the safety monitor
        force uut.a_pace = 1'b1;
        force uut.v_pace = 1'b1;
        #2000000; // 2 ms
        release uut.a_pace;
        release uut.v_pace;
        #10000000; // 10 ms

        $display("==================================================");
        $display("Pacemaker Closed-Loop Integration Testbench Completed");
        $display("==================================================");
        $finish;
    end

endmodule

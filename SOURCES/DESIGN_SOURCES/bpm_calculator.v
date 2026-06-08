`timescale 1ns/1ps

// bpm_calculator.v
// Calculates BPM based on interval between heartbeat_detected pulses.
// Assumes input clock frequency (samples per second) provided as parameter Fs.

module bpm_calculator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        heartbeat_detected,
    output reg [15:0] bpm,                // BPM value (0-65535)
    output reg [1:0]  classification      // 0: Bradycardia, 1: Normal, 2: Tachycardia, 3: Reserved
);
    parameter integer Fs = 1000; // samples per second (default 1kHz)
    // Counter for samples between beats
    reg [31:0] sample_counter;
    reg [31:0] interval_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= 0;
            interval_reg   <= 0;
            bpm            <= 0;
            classification <= 0;
        end else begin
            if (heartbeat_detected) begin
                interval_reg   <= sample_counter + 1; // include current sample
                sample_counter <= 0;
                // Compute BPM: 60 * Fs / interval
                if (interval_reg != 0) begin
                    bpm <= (60 * Fs) / interval_reg;
                end else begin
                    bpm <= 0;
                end
                // Classification
                if (bpm < 60) begin
                    classification <= 0; // Bradycardia
                end else if (bpm <= 100) begin
                    classification <= 1; // Normal
                end else begin
                    classification <= 2; // Tachycardia
                end
            end else begin
                sample_counter <= sample_counter + 1;
            end
        end
    end
endmodule

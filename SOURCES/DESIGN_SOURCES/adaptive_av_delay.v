`timescale 1ns/1ps

module adaptive_av_delay (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] bpm,
    output reg  [31:0] av_delay_cycles
);

    parameter CLK_FREQ_HZ = 1000; // Default 1 kHz (1 ms period)

    localparam CYCLES_180MS = (180 * CLK_FREQ_HZ) / 1000;
    localparam CYCLES_150MS = (150 * CLK_FREQ_HZ) / 1000;
    localparam CYCLES_120MS = (120 * CLK_FREQ_HZ) / 1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            av_delay_cycles <= CYCLES_150MS; // Default to 150ms on reset
        end else begin
            if (bpm < 60) begin
                av_delay_cycles <= CYCLES_180MS;
            end else if (bpm > 80) begin
                av_delay_cycles <= CYCLES_120MS;
            end else begin
                av_delay_cycles <= CYCLES_150MS;
            end
        end
    end

endmodule

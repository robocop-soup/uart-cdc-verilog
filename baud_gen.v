// baud_gen.v
// 16x oversample tick generator for UART. RX uses all 16 ticks per bit
// to find the bit center; TX just uses every 16th one as its bit clock.

module baud_gen #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire clk,
    input  wire rst_n,
    output reg  tick        // 1-cycle pulse at 16x baud rate
);

    // truncation here can cause baud drift on long frames if
    // CLK_FREQ doesn't divide cleanly by BAUD_RATE*16
    localparam integer DIVISOR = CLK_FREQ / (BAUD_RATE * 16);

    reg [$clog2(DIVISOR):0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            tick  <= 1'b0;
        end else if (count == DIVISOR - 1) begin
            count <= 0;
            tick  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            tick  <= 1'b0;
        end
    end

endmodule

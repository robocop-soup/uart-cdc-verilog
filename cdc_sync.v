// cdc_sync.v
// Standard 2-flop synchronizer for crossing a signal into another clock
// domain. One instance per bit - don't use this directly on multi-bit
// buses, since each bit can resolve on a different edge and you'll get
// a value that was never actually driven. Use gray coding, a handshake,
// or an async FIFO for that instead.

module cdc_sync #(
    parameter WIDTH = 1,
    parameter RESET_VAL = {WIDTH{1'b1}}   // UART line idles high
) (
    input  wire             dst_clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] async_in,
    output reg  [WIDTH-1:0] sync_out
);

    reg [WIDTH-1:0] meta_stage;

    always @(posedge dst_clk or negedge rst_n) begin
        if (!rst_n) begin
            meta_stage <= RESET_VAL;
            sync_out   <= RESET_VAL;
        end else begin
            meta_stage <= async_in;   // may go metastable
            sync_out   <= meta_stage; // resolved by now, safe to use
        end
    end

endmodule

// uart_top.v
// TX sits in clk_tx, RX sits in clk_rx. Serial line crosses through a
// synchronizer going one way, rx_valid crosses back through another.

module uart_top #(
    parameter CLK_FREQ_TX  = 50_000_000,
    parameter CLK_FREQ_RX  = 48_000_000,   // different on purpose
    parameter BAUD_RATE    = 115_200
) (
    input  wire       clk_tx,
    input  wire       clk_rx,
    input  wire       rst_n,

    input  wire        tx_start,
    input  wire [7:0]  tx_data,
    output wire         tx_busy,

    output wire [7:0]  rx_data_out,
    output wire         rx_valid_out,
    output wire         rx_valid_tx_dom,
    output wire         frame_error_out
);

    // ---------------- TX domain ----------------
    wire tx_baud_tick;
    wire tx_serial;

    baud_gen #(.CLK_FREQ(CLK_FREQ_TX), .BAUD_RATE(BAUD_RATE)) u_baud_tx (
        .clk   (clk_tx),
        .rst_n (rst_n),
        .tick  (tx_baud_tick)
    );

    uart_tx u_tx (
        .clk      (clk_tx),
        .rst_n    (rst_n),
        .baud_tick(tx_baud_tick),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx       (tx_serial),
        .tx_busy  (tx_busy)
    );

    // serial line: TX domain -> RX domain
    wire rx_serial_sync;

    cdc_sync #(.WIDTH(1), .RESET_VAL(1'b1)) u_cdc_line (
        .dst_clk  (clk_rx),
        .rst_n    (rst_n),
        .async_in (tx_serial),
        .sync_out (rx_serial_sync)
    );

    // ---------------- RX domain ----------------
    wire rx_baud_tick;

    baud_gen #(.CLK_FREQ(CLK_FREQ_RX), .BAUD_RATE(BAUD_RATE)) u_baud_rx (
        .clk   (clk_rx),
        .rst_n (rst_n),
        .tick  (rx_baud_tick)
    );

    uart_rx u_rx (
        .clk        (clk_rx),
        .rst_n      (rst_n),
        .baud_tick  (rx_baud_tick),
        .rx_in      (rx_serial_sync),
        .rx_data    (rx_data_out),
        .rx_valid   (rx_valid_out),
        .frame_error(frame_error_out)
    );

    // rx_valid: RX domain -> TX domain
    // plain 2FF sync on a pulse - fine here since it's wide enough,
    // see README for the caveat
    cdc_sync #(.WIDTH(1), .RESET_VAL(1'b0)) u_cdc_flag (
        .dst_clk  (clk_tx),
        .rst_n    (rst_n),
        .async_in (rx_valid_out),
        .sync_out (rx_valid_tx_dom)
    );

endmodule

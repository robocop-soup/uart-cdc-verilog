// uart_tb.v
// Self-checking testbench. clk_tx and clk_rx run at different rates so
// the CDC path is actually exercised, not just simulated on paper.

`timescale 1ns/1ps

module uart_tb;

    localparam CLK_FREQ_TX = 50_000_000;
    localparam CLK_FREQ_RX = 48_000_000;
    localparam BAUD_RATE   = 115_200;

    reg clk_tx = 0;
    reg clk_rx = 0;
    reg rst_n  = 0;

    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_busy;

    wire [7:0] rx_data_out;
    wire       rx_valid_out;
    wire       rx_valid_tx_dom;
    wire       frame_error_out;

    integer errors = 0;
    integer tests  = 0;

    always #10 clk_tx = ~clk_tx;        // 50MHz
    always #10.4167 clk_rx = ~clk_rx;   // 48MHz

    uart_top #(
        .CLK_FREQ_TX(CLK_FREQ_TX),
        .CLK_FREQ_RX(CLK_FREQ_RX),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk_tx         (clk_tx),
        .clk_rx         (clk_rx),
        .rst_n          (rst_n),
        .tx_start       (tx_start),
        .tx_data        (tx_data),
        .tx_busy        (tx_busy),
        .rx_data_out    (rx_data_out),
        .rx_valid_out   (rx_valid_out),
        .rx_valid_tx_dom(rx_valid_tx_dom),
        .frame_error_out(frame_error_out)
    );

    task send_and_check(input [7:0] data);
        begin
            tests = tests + 1;
            @(posedge clk_tx);
            tx_data  = data;
            tx_start = 1'b1;
            @(posedge clk_tx);
            tx_start = 1'b0;

            fork : wait_or_timeout
                begin
                    @(posedge rx_valid_out);
                    disable wait_or_timeout;
                end
                begin
                    #200000;
                    $display("[%0t] TIMEOUT waiting for byte 0x%02h", $time, data);
                    errors = errors + 1;
                    disable wait_or_timeout;
                end
            join

            if (rx_data_out !== data) begin
                $display("[%0t] FAIL: sent 0x%02h, got 0x%02h", $time, data, rx_data_out);
                errors = errors + 1;
            end else if (frame_error_out) begin
                $display("[%0t] FAIL: frame error on byte 0x%02h", $time, data);
                errors = errors + 1;
            end else begin
                $display("[%0t] PASS: byte 0x%02h received correctly", $time, data);
            end

            wait (tx_busy == 1'b0);
            @(posedge clk_tx);
        end
    endtask

    integer i;
    reg [7:0] rand_byte;

    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);

        tx_start = 0;
        tx_data  = 8'h00;
        rst_n    = 0;
        repeat (5) @(posedge clk_tx);
        rst_n = 1;
        repeat (5) @(posedge clk_tx);

        // directed: all-zero, all-one, alternating patterns, LSB/MSB extremes
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h55);
        send_and_check(8'hAA);
        send_and_check(8'h01);
        send_and_check(8'h80);

        // random
        for (i = 0; i < 5; i = i + 1) begin
            rand_byte = $random;
            send_and_check(rand_byte);
        end

        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL %0d TESTS PASSED", tests);
        else
            $display("%0d of %0d TESTS FAILED", errors, tests);
        $display("--------------------------------------------------");

        #1000;
        $finish;
    end

    initial begin
        #5_000_000;
        $display("GLOBAL TIMEOUT - simulation did not finish in time");
        $finish;
    end

endmodule

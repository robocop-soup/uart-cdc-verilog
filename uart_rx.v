// uart_rx.v
// RX FSM, oversampled at 16x. rx_in is assumed already synchronized
// (see cdc_sync.v) before it gets here.

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       baud_tick,
    input  wire       rx_in,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        frame_error
);

    localparam IDLE       = 3'd0,
               START_CONF = 3'd1,
               DATA       = 3'd2,
               STOP       = 3'd3;

    reg [2:0] state;
    reg [3:0] tick_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            tick_cnt    <= 4'd0;
            bit_idx     <= 3'd0;
            shift_reg   <= 8'd0;
            rx_data     <= 8'd0;
            rx_valid    <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (rx_in == 1'b0) begin   // possible start bit
                        tick_cnt <= 4'd0;
                        state    <= START_CONF;
                    end
                end

                // check the line is still low at tick 7 (mid start-bit)
                // before committing - filters out short glitches
                START_CONF: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd7) begin
                            if (rx_in == 1'b0) begin
                                tick_cnt <= 4'd0;
                                bit_idx  <= 3'd0;
                                state    <= DATA;
                            end else begin
                                state <= IDLE;   // false start
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            shift_reg[bit_idx] <= rx_in;
                            if (bit_idx == 3'd7) begin
                                state <= STOP;
                            end else begin
                                bit_idx <= bit_idx + 1'b1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
                            rx_data     <= shift_reg;
                            rx_valid    <= 1'b1;
                            frame_error <= (rx_in != 1'b1);
                            tick_cnt    <= 4'd0;
                            state       <= IDLE;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

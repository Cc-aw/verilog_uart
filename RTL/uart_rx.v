module uart_rx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 9600
) (
    input clk,
    input rst_n,
    input i_uart_rx,

    output reg [7:0] o_uart_data,
    output reg       o_data_valid
);

    ////-------------------------------------------
    //  下降沿检测
    ////-------------------------------------------
    reg  dff0_uart_rx;
    reg  dff1_uart_rx;
    reg  uart_rx_last;

    wire nedge_uart_rx;

    always @(posedge clk) begin
        dff0_uart_rx <= i_uart_rx;
        dff1_uart_rx <= dff0_uart_rx;
        uart_rx_last <= dff1_uart_rx;
    end

    assign nedge_uart_rx = (uart_rx_last == 1) && (dff1_uart_rx == 0);

    ////-------------------------------------------
    //  FSM
    ////-------------------------------------------

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] RX = 2'd2;
    localparam [1:0] STOP = 2'd3;
    reg [1:0] state = 2'd0;

    parameter MCNT_BAUD = CLOCK_FREQ / BAUD_RATE - 1;
    reg [12 : 0] baud_cnt = 13'd0;

    reg [   7:0] r_data = 8'd0;
    reg [   2:0] bit_id;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state        <= IDLE;
            r_data       <= 0;
            o_data_valid <= 0;
            bit_id       <= 0;
            baud_cnt     <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    o_data_valid <= 0;
                    baud_cnt     <= 0;
                    if (nedge_uart_rx) begin
                        state  <= START;
                        bit_id <= 0;
                    end
                end

                START: begin
                    baud_cnt <= baud_cnt + 1;
                    if (baud_cnt == MCNT_BAUD / 2) begin
                        if (dff1_uart_rx == 0) begin  //起始位检测
                            state    <= RX;
                            bit_id   <= 0;
                            baud_cnt <= 0;
                        end
                        else begin
                            state <= IDLE;
                        end
                    end
                end

                RX: begin
                    baud_cnt <= baud_cnt + 1;
                    if (baud_cnt == MCNT_BAUD) begin
                        baud_cnt       <= 0;
                        r_data[bit_id] <= dff1_uart_rx;
                        if (bit_id == 7) begin
                            state <= STOP;
                        end
                        else begin
                            bit_id <= bit_id + 1;
                        end
                    end
                end

                STOP: begin
                    baud_cnt <= baud_cnt + 1;
                    if (baud_cnt == MCNT_BAUD) begin
                        if (dff1_uart_rx == 1) begin  // STOP位检查
                            o_uart_data  <= r_data;
                            o_data_valid <= 1;
                        end
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

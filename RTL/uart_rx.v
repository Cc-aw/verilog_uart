module uart_rx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 9600,
    parameter EN_PARITY  = 00           //00:no parity , 11 : ODD , 01 : EVEN
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
    reg d1_rx, d2_rx, d3_rx;
    wire nedge_uart_rx;

    always @(posedge clk) begin
        d1_rx <= i_uart_rx;
        d2_rx <= d1_rx;
        d3_rx <= d2_rx;
    end

    assign nedge_uart_rx = (d3_rx == 1) && (d2_rx == 0);
    ////------------------------------
    // 计算校验位PARITY
    ////------------------------------
    function [0:0] get_parity;
        input [7:0] data;
        input [1:0] mode;
        begin
            case (mode)
                2'b11:   get_parity = ~(^data);
                2'b01:   get_parity = ^data;
                default: get_parity = 1;
            endcase
        end
    endfunction

    ////-------------------------------------------
    //  FSM
    ////-------------------------------------------

    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] START = 3'b001;
    localparam [2:0] RX = 3'b010;
    localparam [2:0] PARITY = 3'b011;
    localparam [2:0] STOP = 3'b100;
    reg [2:0] state = 3'd0;

    parameter MCNT_BAUD = CLOCK_FREQ / BAUD_RATE - 1;
    reg  [12 : 0] baud_cnt = 13'd0;

    reg  [   7:0] r_data = 8'd0;
    reg  [   2:0] bit_id;

    wire          parity_en = |EN_PARITY;  // 只要 EN_PARITY ≠ 00 就启用校验

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
                        if (d2_rx == 0) begin  //起始位检测
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
                        r_data[bit_id] <= d2_rx;
                        if (bit_id == 7) begin
                            state <= parity_en ? PARITY : STOP;
                        end
                        else begin
                            bit_id <= bit_id + 1;
                        end
                    end
                end

                //校验位检测
                PARITY: begin
                    baud_cnt <= baud_cnt + 1;
                    if (baud_cnt == MCNT_BAUD) begin
                        baud_cnt <= 0;
                        state    <= (d2_rx == get_parity(r_data, EN_PARITY)) ? STOP : IDLE;
                    end
                end
                
                STOP: begin
                    baud_cnt <= baud_cnt + 1;
                    if (baud_cnt == MCNT_BAUD) begin
                        if (d2_rx == 1) begin  // STOP位检查
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

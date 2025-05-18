module uart_tx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 9600,
    parameter EN_PARITY  = 00           //00:no parity , 11 : ODD , 01 : EVEN
) (
    input            clk,
    input            rst_n,
    //
    input      [7:0] i_uart_data,
    input            i_uart_en,
    //
    output reg       o_uart_tx,
    output reg       o_uart_busy
);

    ////------------------------------
    // 上升沿检测 
    ////------------------------------
    reg i_uart_en_d;  // i_uart_en_d 保存上一周期的 i_uart_en
    reg en;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i_uart_en_d <= 0;
            en          <= 0;
        end
        else begin
            // 检测到 i_uart_en 从 0 -> 1 就拉高 en_pulse 一拍
            en          <= i_uart_en & ~i_uart_en_d;
            // 更新延迟寄存器
            i_uart_en_d <= i_uart_en;
        end
    end

    ////------------------------------
    // 暂存 i_uart_data
    ////------------------------------
    reg [7:0] data_ff;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            data_ff <= 0;
        end
        else if (en) begin
            data_ff <= i_uart_data;
        end
    end

    ////------------------------------
    // 计算校验位PARITY
    ////------------------------------
    wire bit_parity;

    function [0:0] get_parity;
        input [7:0] data;
        input [1:0] mode;
        begin
            case (mode)
                2'b11:      get_parity = ~(^data);
                2'b01:      get_parity = ^data;
                default: get_parity = 1;
            endcase
        end
    endfunction
    
    assign bit_parity = get_parity(data_ff, EN_PARITY);

    ////------------------------------
    // FSM
    ////------------------------------
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] START = 3'b001;
    localparam [2:0] TX = 3'b010;
    localparam [2:0] PARITY = 3'b011;
    localparam [2:0] STOP = 3'b100;

    reg [ 2:0] state = IDLE;

    reg [12:0] baud_cnt;
    reg [ 2:0] bit_addr;
    parameter MCNT_TX = CLOCK_FREQ / BAUD_RATE - 1;

    wire parity_en = |EN_PARITY;  // 只要 EN_PARITY ≠ 00 就启用校验

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state       <= IDLE;
            o_uart_tx   <= 1;
            o_uart_busy <= 0;
            bit_addr    <= 0;
            baud_cnt    <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (en) begin
                        state       <= START;
                        o_uart_busy <= 1;
                        baud_cnt    <= 0;
                        bit_addr    <= 0;
                    end
                    else begin
                        o_uart_tx   <= 1;
                        o_uart_busy <= 0;
                    end
                end

                //(1) 起始位 0
                START: begin
                    o_uart_tx <= 0;
                    if (baud_cnt == MCNT_TX) begin
                        baud_cnt <= 0;
                        state    <= TX;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                //(2) 8 bit数据 低字节优先
                TX: begin
                    o_uart_tx <= data_ff[bit_addr];
                    if (baud_cnt == MCNT_TX) begin
                        baud_cnt <= 0;
                        if (bit_addr == 7) begin
                            bit_addr <= 0;
                            state    <= parity_en ? PARITY : STOP;
                        end
                        else begin
                            bit_addr <= bit_addr + 1;
                        end
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                // 校验位
                PARITY: begin
                    o_uart_tx <= bit_parity;
                    if (baud_cnt == MCNT_TX) begin
                        baud_cnt <= 0;
                        state    <= STOP;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                //(3) 停止位 1
                STOP: begin
                    o_uart_tx <= 1;
                    if (baud_cnt == MCNT_TX) begin
                        state    <= IDLE;
                        baud_cnt <= 0;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

module uart_tx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 9600
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

    reg [ 7:0] data_ff;
    reg [12:0] tx_cnt;
    reg [ 2:0] bit_addr;
    parameter MCNT_TX = CLOCK_FREQ / BAUD_RATE - 1;

    // 上升沿检测：i_uart_en_d 保存上一周期的 i_uart_en
    reg i_uart_en_d;
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


    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] START = 2'b01;
    localparam [1:0] TX = 2'b10;
    localparam [1:0] STOP = 2'b11;

    reg [1:0] state = IDLE;  //FSM

    ////------------------------------
    // FSM //
    ////------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state       <= IDLE;
            o_uart_tx   <= 1;
            o_uart_busy <= 0;
            bit_addr    <= 0;
            tx_cnt      <= 0;
            data_ff     <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (en) begin
                        data_ff     <= i_uart_data;
                        state       <= START;
                        o_uart_busy <= 1;
                        tx_cnt      <= 0;
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
                    if (tx_cnt == MCNT_TX) begin
                        tx_cnt <= 0;
                        state  <= TX;
                    end
                    else begin
                        tx_cnt <= tx_cnt + 1;
                    end
                end

                //(2) 8 bit数据 低字节优先
                TX: begin
                    o_uart_tx <= data_ff[bit_addr];
                    if (tx_cnt == MCNT_TX) begin
                        tx_cnt <= 0;
                        if (bit_addr == 7) begin
                            bit_addr <= 0;
                            state    <= STOP;
                        end
                        else begin
                            bit_addr <= bit_addr + 1;
                        end
                    end
                    else begin
                        tx_cnt <= tx_cnt + 1;
                    end
                end

                //(3) 停止位 1
                STOP: begin
                    o_uart_tx <= 1;
                    if (tx_cnt == MCNT_TX) begin
                        state  <= IDLE;
                        tx_cnt <= 0;
                    end
                    else begin
                        tx_cnt <= tx_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule

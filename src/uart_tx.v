// UART.v
module uart_tx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 9600
) (
    input             clk,
    input             rst_n,
    //
    input       [7:0] i_uart_data,
    input             i_uart_en,
    //
    output reg        o_uart_tx,
    output wire       o_uart_busy
);

    reg [7:0] r_uart_data;
    reg       r_uart_en;

    always @(posedge clk) begin
        r_uart_en <= i_uart_en;
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_uart_data <= 8'd0;
        end
        else if (r_uart_en && ~en) begin
            r_uart_data <= i_uart_data;
        end
    end

    parameter MCNT_DIV = CLOCK_FREQ / BAUD_RATE - 1;
    reg        en;
    reg [12:0] div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            div_cnt <= 0;
        end
        else if (div_cnt == MCNT_DIV) begin
            div_cnt <= 0;
        end
        else begin
            div_cnt <= div_cnt + 1;
        end
    end

    reg [3:0] bit_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bit_cnt <= 0;
        end
        else if ((div_cnt == MCNT_DIV) && en) begin
            if (bit_cnt == 9) begin
                bit_cnt <= 0;
            end
            else begin
                bit_cnt <= bit_cnt + 1;
            end
        end
        else begin
            bit_cnt <= bit_cnt;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            en <= 0;
        end
        else if (r_uart_en && ~en) begin
            en <= 1;
        end
        else if ((div_cnt == MCNT_DIV) && bit_cnt == 9) begin
            en <= 0;
        end
        else begin
            en <= en;
        end
    end

    reg r_uart_tx;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_uart_tx <= 1;
        end
        else if (en) begin
            case (bit_cnt)
                0:       r_uart_tx <= 0;
                1:       r_uart_tx <= r_uart_data[0];
                2:       r_uart_tx <= r_uart_data[1];
                3:       r_uart_tx <= r_uart_data[2];
                4:       r_uart_tx <= r_uart_data[3];
                5:       r_uart_tx <= r_uart_data[4];
                6:       r_uart_tx <= r_uart_data[5];
                7:       r_uart_tx <= r_uart_data[6];
                8:       r_uart_tx <= r_uart_data[7];
                9:       r_uart_tx <= 1;
                default: r_uart_tx <= r_uart_tx;
            endcase
        end
        else begin
            r_uart_tx <= 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            o_uart_tx <= 1;
        end
        else begin
            o_uart_tx <= r_uart_tx;
        end
    end

    assign o_uart_busy = en;



endmodule

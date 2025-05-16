// UART_tb.v
`timescale 1ns / 1ps
`define VCD_PATH "build/wave.vcd"
module tb_uart_tx;
    reg clk = 1;
    reg rst_n;
    reg [7:0] i_uart_data;
    reg i_uart_en;
    wire o_uart_tx;
    wire o_uart_busy;

    always #10 clk = ~clk;

    initial begin
        rst_n = 0;
        i_uart_en = 0;
        #201;
        rst_n = 1;

        //第一个字节
        i_uart_data = 8'b1010_0101;
        i_uart_en = 1;
        #20;
        i_uart_en = 0;
        #200_000;//等待busy信号拉高

        wait(~o_uart_busy);
        #200_001;

        //第二个字节
        i_uart_en = 1;
        i_uart_data = 8'b0110_0110;
        #20;
        i_uart_en = 0;
        #200_000;//等待busy信号拉高

        wait(~o_uart_busy);
        #200_000;

        $finish;
    end

    uart_tx #(
      .BAUD_RATE(115200)
    )
    u_uart_tx 
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .i_uart_data(i_uart_data),
        .i_uart_en  (i_uart_en),
        .o_uart_tx  (o_uart_tx),
        .o_uart_busy(o_uart_busy)
    );

    initial begin
        $dumpfile(`VCD_PATH);
        $dumpvars(0, tb_uart_tx);
    end

endmodule

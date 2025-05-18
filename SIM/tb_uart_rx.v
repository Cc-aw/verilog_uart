// UART_tb.v
`timescale 1ns / 1ps
`define VCD_PATH "build/rx_wave.vcd"

module tb_uart_rx;

    // 参数
    parameter CLOCK_FREQ = 50_000_000;
    parameter BAUD_RATE = 9600;
    parameter CLK_PERIOD = 20;  // 50MHz -> 20ns
    parameter BAUD_PERIOD = 1_000_000_000 / BAUD_RATE;  // ns
    parameter EN_PARITY  = 11 ;

    // DUT 接口信号
    reg        clk;
    reg        rst_n;
    reg        i_uart_rx;
    wire [7:0] o_uart_data;
    wire       o_data_valid;

    // 实例化 DUT
    uart_rx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .EN_PARITY (EN_PARITY)
    ) uut (
        .clk         (clk),
        .rst_n       (rst_n),
        .i_uart_rx   (i_uart_rx),
        .o_uart_data (o_uart_data),
        .o_data_valid(o_data_valid)
    );

    // 时钟生成
    always #(CLK_PERIOD / 2) clk = ~clk;

    // 发送 UART 字节任务（起始位 + 数据位 + 停止位）
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            // 起始位（低电平）
            i_uart_rx = 0;
            #(BAUD_PERIOD);

            // 数据位（LSB first）
            for (i = 0; i < 8; i = i + 1) begin
                i_uart_rx = data[i];
                #(BAUD_PERIOD);
            end

            //校验位 ODD:1, EVEN:0
            i_uart_rx = (EN_PARITY == 11) ? ~(^data) : (^data);
            $display("校验位为 %b", i_uart_rx);
            #(BAUD_PERIOD);
            // 停止位（高电平）
            i_uart_rx = 1;
            #(BAUD_PERIOD);
        end
    endtask

    initial begin
        $display("Starting UART RX testbench...");
        clk       = 0;
        rst_n     = 0;
        i_uart_rx = 1;  // 空闲状态为高电平

        // 复位
        #(CLK_PERIOD * 10);
        rst_n = 1;

        // 稍作等待
        #(CLK_PERIOD * 100);

        // 发送第一个字节 8'hA5 = 8'b10100101
        send_uart_byte(8'hA5);

        // 等待一段时间，观察输出
        #(BAUD_PERIOD * 3);
        if (o_uart_data == 8'hA5) $display("✅ Test passed: Received 0x%02X", o_uart_data);
        else $display("❌ Test failed: Received 0x%02X", o_uart_data);

        // 发送第2个字节 8'b00001110
        send_uart_byte(8'b00001110);

        // 等待一段时间，观察输出
        #(BAUD_PERIOD * 3);
        if (o_uart_data == 8'b00001110) $display("✅ Test passed: Received 0x%02X", o_uart_data);
        else $display("❌ Test failed: Received 0x%02X", o_uart_data);

        $finish;
    end

    initial begin
        $dumpfile(`VCD_PATH);
        $dumpvars(0, tb_uart_rx);
    end

endmodule








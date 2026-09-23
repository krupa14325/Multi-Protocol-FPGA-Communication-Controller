
module spi_top_tb;
    reg clk, rst, start;
    reg cpol, cpha;
    wire sck, mosi, miso, ss, done, busy, error;
    wire [7:0] miso_data;
    wire [7:0] rx_data;
    wire data_ready;

    // Instantiate Master
    spi_master #(.CLK_DIV(2)) master_inst (
        .clk(clk),
        .rst(rst),
        .mosi_data(8'b10101010),
        .start(start),
        .miso(miso),
        .cpol(cpol),
        .cpha(cpha),
        .miso_data(miso_data),
        .sck(sck),
        .mosi(mosi),
        .ss(ss),
        .done(done),
        .busy(busy),
        .error(error)
    );

    // Instantiate Slave
    spi_slave slave_inst (
        .sck(sck),
        .ss(ss),
        .mosi(mosi),
        .miso(miso),
        .cpol(cpol),
        .cpha(cpha),
        .tx_data(8'b11001100),   // Slave sends this data
        .rx_data(rx_data),
        .data_ready(data_ready)
    );

    // System Clock
    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 1; start = 0;
        cpol = 0; cpha = 0; // Mode 0 for example
        #20 rst = 0;
        #20 start = 1;
        #10 start = 0;
        #300 $finish;
    end
endmodule

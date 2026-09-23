

// -----------------------------------------------------------------------------
// Testbench
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_i2c();
    reg clk;
    reg rst_n;

    // wires
    wire sda;
    wire scl;

    // Master signals
    reg start;
    reg rw;
    reg [6:0] addr;
    reg [7:0] tx_byte;
    wire [7:0] rx_byte;
    wire busy, done;

    // Instantiate master
    i2c_master #(.CLK_DIV(4)) master (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .rw(rw),
        .addr(addr),
        .tx_byte(tx_byte),
        .rx_byte(rx_byte),
        .busy(busy),
        .done(done),
        .sda(sda),
        .scl(scl)
    );

    // Simple behavioral slave (not fully implemented), tie sda high for now
    // A full TB would implement proper slave behavior.

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    initial begin
        rst_n = 0;
        start = 0;
        rw = 0;
        addr = 7'h50; // example
        tx_byte = 8'hA5;
        #100;
        rst_n = 1;
        #200;
        // start transaction
        start = 1;
        #10;
        start = 0;
        #2000;
        $finish;
    end

endmodule

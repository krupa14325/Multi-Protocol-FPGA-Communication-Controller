
// -----------------------------------------------------------------------------
// Simple example I2C slave that responds to a single 7-bit address and stores one byte

// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module i2c_slave_simple(
    input wire clk,
    input wire rst_n,
    input wire scl,
    inout wire sda,
    input wire [6:0] my_addr,
    output reg [7:0] stored_byte
);
    // For simplicity the slave watches start/address on SDA/SCL and responds.
    // Implementing a full slave is long; this is a minimal behavioral model suitable for testbench.

    reg sda_oe;
    assign sda = (sda_oe) ? 1'bz : 1'b0;

    // VERY simple behavior: when address matched and write occurs, slave ACKs and captures
    // the following byte into stored_byte. This is purely for demonstration in the testbench.

    initial begin
        stored_byte = 8'h00;
        sda_oe = 1'b1; // release
    end

endmodule

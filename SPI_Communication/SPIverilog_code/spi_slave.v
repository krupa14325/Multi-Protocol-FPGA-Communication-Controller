module spi_slave (
    input  wire        sck,          // SPI clock from master
    input  wire        ss,           // Slave select (active low)
    input  wire        mosi,         // Master ? Slave data
    output reg         miso,         // Slave ? Master data
    input  wire        cpol,         // Clock polarity
    input  wire        cpha,         // Clock phase
    input  wire [7:0]  tx_data,      // Data to send to master
    output reg  [7:0]  rx_data,      // Data received from master
    output reg         data_ready    // Indicates received data valid
);

    reg [7:0] shift_in;   // Incoming bits
    reg [7:0] shift_out;  // Outgoing bits
    reg [2:0] bit_cnt;    // Bit counter (0?7)

    // Detect edges based on CPOL
    wire leading_edge  = (cpol == 0) ?  (sck == 1) : (sck == 0);
    wire trailing_edge = (cpol == 0) ?  (sck == 0) : (sck == 1);

    always @(negedge ss) begin
        // When slave is selected, prepare to send data
        shift_out <= tx_data;
        bit_cnt <= 7;
        data_ready <= 0;
    end

    always @(posedge sck or negedge sck) begin
        if (!ss) begin
            // Determine correct edge for sampling and shifting
            if (cpha == 0) begin
                // CPHA = 0 ? sample on leading, shift on trailing
                if (leading_edge) begin
                    shift_in[bit_cnt] <= mosi; // Read data
                end else if (trailing_edge) begin
                    miso <= shift_out[bit_cnt]; // Send data
                    if (bit_cnt == 0)
                        bit_cnt <= 7;
                    else
                        bit_cnt <= bit_cnt - 1;
                end
            end else begin
                // CPHA = 1 ? shift on leading, sample on trailing
                if (leading_edge) begin
                    miso <= shift_out[bit_cnt]; // Send data
                end else if (trailing_edge) begin
                    shift_in[bit_cnt] <= mosi;  // Read data
                    if (bit_cnt == 0)
                        bit_cnt <= 7;
                    else
                        bit_cnt <= bit_cnt - 1;
                end
            end
        end
    end

    // Latch received data when SS goes high again
    always @(posedge ss) begin
        rx_data <= shift_in;
        data_ready <= 1;
    end
endmodule

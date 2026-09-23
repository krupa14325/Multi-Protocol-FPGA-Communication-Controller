
module spi_master #(
    parameter CLK_DIV = 4   // Clock divider for SCK speed
)(
    input  wire        clk,          // System clock
    input  wire        rst,          // Reset
    input  wire [7:0]  mosi_data,    // Data to transmit
    input  wire        start,        // Start transfer
    input  wire        miso,         // Data from slave

    input  wire        cpol,         // Clock polarity
    input  wire        cpha,         // Clock phase

    output reg  [7:0]  miso_data,    // Data received
    output reg         sck,          // SPI clock
    output reg         mosi,         // Master Out
    output reg         ss,           // Slave select
    output reg         done,         // Done flag
    output reg         busy,         // Busy flag
    output reg         error         // Error flag (for invalid start)
);

    // FSM states
    localparam IDLE = 2'b00,
               LOAD = 2'b01,
               TRANSFER = 2'b10,
               DONE = 2'b11;

    reg [1:0] state;
    reg [2:0] bit_cnt;          // Bit counter (0?7)
    reg [7:0] shift_reg;        // Data shift register
    reg [7:0] recv_reg;         // Received bits
    reg [7:0] clk_div_cnt;      // Clock divider counter
    reg sck_en;                 // Internal clock enable toggle

    // SPI clock generation with divider
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div_cnt <= 0;
            sck_en <= 0;
        end else if (busy) begin
            if (clk_div_cnt == (CLK_DIV - 1)) begin
                clk_div_cnt <= 0;
                sck_en <= 1;
            end else begin
                clk_div_cnt <= clk_div_cnt + 1;
                sck_en <= 0;
            end
        end else begin
            clk_div_cnt <= 0;
            sck_en <= 0;
        end
    end

    // Main FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            sck <= 0;
            ss <= 1;
            done <= 0;
            busy <= 0;
            error <= 0;
            mosi <= 0;
            bit_cnt <= 0;
            miso_data <= 0;
        end else begin
            case (state)
                // ------------------ IDLE ------------------
                IDLE: begin
                    done <= 0;
                    busy <= 0;
                    ss <= 1;
                    sck <= cpol;
                    if (start) begin
                        busy <= 1;
                        error <= 0;
                        state <= LOAD;
                    end
                end

                // ------------------ LOAD ------------------
                LOAD: begin
                    ss <= 0; // Activate slave
                    shift_reg <= mosi_data;
                    bit_cnt <= 7;
                    sck <= cpol;
                    state <= TRANSFER;
                end

                // ------------------ TRANSFER ------------------
                TRANSFER: begin
                    if (sck_en) begin
                        // Toggle SCK based on CPOL
                        sck <= ~sck;

                        // Data sampling and shifting based on CPHA
                        if ((sck == ~cpol && cpha == 0) || (sck == cpol && cpha == 1)) begin
                            // Shift out data
                            mosi <= shift_reg[bit_cnt];
                        end else begin
                            // Sample data
                            recv_reg[bit_cnt] <= miso;
                            if (bit_cnt == 0)
                                state <= DONE;
                            else
                                bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                // ------------------ DONE ------------------
                DONE: begin
                    ss <= 1;
                    sck <= cpol;
                    done <= 1;
                    busy <= 0;
                    miso_data <= recv_reg;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

# Digital Communication Protocol
## Demo
<img width="2720" height="1840" alt="uart_duplex_architecture" src="https://github.com/user-attachments/assets/189b4f4d-8516-40f2-a5e7-946b7a27d929" />
<img width="1080" height="715" alt="Screenshot 2026-07-22 180645" src="https://github.com/user-attachments/assets/505633a4-5e2e-4809-8b97-fd46c88a7a7f" />



A Verilog/SystemVerilog collection of digital communication protocol implementations — **UART**, **SPI**, and **I2C** — designed for functional simulation (ModelSim) and FPGA deployment.

This repository is organized into three independent protocol folders, each containing RTL source, a self-checking or stimulus-driven testbench, and simulation waveform screenshots for reference.

---

## Table of Contents

- [Repository Structure](#repository-structure)
- [1. UART — Full-Duplex Asynchronous Transceiver](#1-uart--full-duplex-asynchronous-transceiver)
- [2. SPI — Serial Peripheral Interface](#2-spi--serial-peripheral-interface)
- [3. I2C — Inter-Integrated Circuit Bus](#3-i2c--inter-integrated-circuit-bus)
- [Simulation Instructions](#simulation-instructions)
- [Roadmap](#roadmap)
- [License](#license)

---

## Repository Structure

```
Digital_Communication_Protocol/
├── UART_Shivansh/
│   ├── BaudGenT.sv         # Baud rate clock generator (transmitter side)
│   ├── BaudGenR.sv         # Baud rate clock generator (receiver side)
│   ├── Parity.sv           # Parity bit generation (odd/even/none)
│   ├── PISO.sv             # Parallel-in Serial-out shift register (Tx framing)
│   ├── SIPO.sv             # Serial-in Parallel-out shift register (Rx sampling)
│   ├── DeFrame.sv          # Frame decomposition (start/stop/parity/data)
│   ├── ErrorCheck.sv       # Parity/start/stop error detection
│   ├── TxUnit.sv           # Top-level transmitter
│   ├── RxUnit.sv           # Top-level receiver
│   ├── Duplex.sv           # Top-level full-duplex UART (Tx + Rx)
│   └── DuplexTest.sv       # Testbench for the Duplex module
│
├── SPI_Communication/
│   ├── SPIverilog_code/
│   │   ├── spi_master.v    # SPI master (CPOL/CPHA configurable)
│   │   ├── spi_slave.v     # SPI slave
│   │   └── spi_tb.v        # Master-slave loopback testbench
│   ├── SPI_sim.png
│   └── SPI_simulation.png
│
├── I2C_Communication/
│   ├── I2C_Master.v        # I2C master (7-bit addressing, single byte R/W)
│   ├── I2C_Slave.v         # Minimal behavioral I2C slave model
│   ├── I2C_TB.v            # Testbench
│   └── I2c_waveform.png
│
├── Simulation.png / Transcript.png / Screenshot ....png   # UART sim evidence
└── README.md
```

---

## 1. UART — Full-Duplex Asynchronous Transceiver

Located in `UART_Shivansh/`. Implements a complete, modular full-duplex UART with configurable baud rate and parity, following an architecture split into small single-responsibility blocks.

### Top module: `Duplex`

```verilog
module Duplex (
    input  wire        reset_n,       // Active-low reset
    input  wire        send,          // Enable to start sending data
    input  wire        clock,         // Main system clock
    input  wire [1:0]  parity_type,   // Parity mode agreed by Tx/Rx
    input  wire [1:0]  baud_rate,     // Baud rate agreed by Tx/Rx
    input  wire [7:0]  data_in,       // Parallel data to transmit

    output wire        tx_active_flag,
    output wire        tx_done_flag,
    output wire        rx_active_flag,
    output wire        rx_done_flag,
    output wire [7:0]  data_out,
    output wire [2:0]  error_flag
);
```

### Sub-modules

| Module | Role |
|---|---|
| `BaudGenT` / `BaudGenR` | Divide the 50 MHz system clock down to the Tx/Rx baud clock for the selected `baud_rate` |
| `Parity` | Computes the parity bit for a given `data_in` and `parity_type` (odd / even / none) |
| `PISO` | Parallel-in Serial-out: frames start bit + 8 data bits + parity bit + stop bit and shifts them out serially over 11 baud clock cycles |
| `SIPO` | Serial-in Parallel-out: samples the incoming serial line at the baud clock and reconstructs the 11-bit frame |
| `DeFrame` | Splits the reconstructed frame into `start_bit`, `data`, `parity_bit`, `stop_bit` |
| `ErrorCheck` | Compares received start/stop/parity bits against expected values and raises a 3-bit `error_flag` (`[0]`=parity error, `[1]`=start error, `[2]`=stop error) |
| `TxUnit` | Wires together `BaudGenT` + `Parity` + `PISO` into a complete transmitter |
| `RxUnit` | Wires together `BaudGenR` + `SIPO` + `DeFrame` + `ErrorCheck` into a complete receiver |
| `Duplex` | Instantiates one `TxUnit` and one `RxUnit` for simultaneous send/receive |

### Configuration encodings

**Parity type (`parity_type[1:0]`):**
| Value | Meaning |
|---|---|
| `00` | No parity |
| `01` | Odd parity |
| `10` | Even parity |
| `11` | No parity |

**Baud rate (`baud_rate[1:0]`):** selects between four supported baud rates (encoded internally as `BAUD24`, `BAUD48`, etc. inside `BaudGenT`/`BaudGenR`).

### Testbench: `DuplexTest`

`DuplexTest.sv` instantiates `Duplex` as the DUT, drives `reset_n`, `send`, `data_in`, `parity_type`, and `baud_rate`, and logs every signal transition to the transcript. The run finishes with a `$stop` (observed at simulation time 2450 us in the reference run), after which the wave window can be inspected for `data_in`, `data_out`, `tx/rx active/done` flags, and `error_flag`.

Observed behavior from the reference simulation:
- With `parity_type = 01` (odd) and clean data, `data_out` correctly mirrors `data_in` after the Rx done flag asserts, with `error_flag = 000`.
- Changing `parity_type` mid-run to `10` while sending the same byte pattern (`5c`) produces a non-zero `error_flag = 001`, i.e. a parity mismatch — confirming the error-check path is functionally exercised.

---

## 2. SPI — Serial Peripheral Interface

Located in `SPI_Communication/`. Implements a configurable master and slave with selectable clock polarity/phase (CPOL/CPHA), suitable for all four standard SPI modes.

### `spi_master`

```verilog
module spi_master #(
    parameter CLK_DIV = 4        // Clock divider controlling SCK frequency
)(
    input  wire       clk, rst,
    input  wire [7:0] mosi_data, // Byte to transmit
    input  wire       start,     // Pulse to begin a transfer
    input  wire       miso,      // Serial data in from slave

    input  wire       cpol,      // Clock polarity
    input  wire       cpha,      // Clock phase

    output reg [7:0]  miso_data, // Byte received from slave
    output reg        sck,       // Generated SPI clock
    output reg        mosi,      // Serial data out to slave
    output reg        ss,        // Slave select
    output reg        done,      // Transfer complete
    output reg        busy,      // Transfer in progress
    output reg        error      // Invalid start condition
);
```

### `spi_slave`

```verilog
module spi_slave (
    input  wire       sck, ss,
    input  wire       mosi,
    output reg        miso,
    input  wire       cpol, cpha,
    input  wire [7:0] tx_data,     // Byte to return to master
    output reg [7:0]  rx_data,     // Byte captured from master
    output reg        data_ready
);
```

Edge detection inside the slave is derived directly from `cpol`/`cpha` (`leading_edge` / `trailing_edge`), so both are wired to sample/shift on the correct clock edge for any of the 4 SPI modes.

### Testbench: `spi_top_tb`

`spi_tb.v` instantiates `spi_master` (with `CLK_DIV = 2`) and `spi_slave` back-to-back (`mosi`→`mosi`, `miso`→`miso`, `sck`→`sck`, `ss`→`ss`) and drives a full-duplex byte exchange, e.g. master sends `8'b10101010` while checking the slave's returned byte via `miso_data`. Waveforms are saved in `SPI_sim.png` and `SPI_simulation.png`.

---

## 3. I2C — Inter-Integrated Circuit Bus

Located in `I2C_Communication/`. A compact, educational I2C master with a matching minimal slave model, sufficient to exercise a single-byte read/write transaction over a shared open-drain `SDA` line.

### `i2c_master`

```verilog
module i2c_master #(
    parameter CLK_DIV = 250          // SCL ≈ clk / (2 * CLK_DIV)
)(
    input  wire        clk, rst_n,
    input  wire        start,        // Pulse to begin a transaction
    input  wire        rw,           // 0 = write, 1 = read
    input  wire [6:0]  addr,         // 7-bit slave address
    input  wire [7:0]  tx_byte,      // Byte to write (master -> slave)
    output reg  [7:0]  rx_byte,      // Byte read (slave -> master)
    output reg         busy,
    output reg         done
);
```

- Supports **7-bit addressing** and single-byte **write or read**.
- `SDA` is modeled as `inout` with tri-state (open-drain) driving, matching real I2C bus behavior.
- `SCL` is driven entirely by the master; the divider `CLK_DIV` sets its frequency.

### `i2c_slave_simple`

```verilog
module i2c_slave_simple(
    input  wire        clk, rst_n,
    input  wire        scl,
    inout  wire        sda,
    input  wire [6:0]  my_addr,
    output reg  [7:0]  stored_byte
);
```

A minimal behavioral slave: watches for a matching address on the bus, ACKs, and captures the following byte into `stored_byte`. It's intentionally simplified (single address, single byte) to keep the testbench self-contained rather than modeling a production-grade slave.

> **Note:** as called out in the source comments, this implementation is educational — it does **not** yet include clock stretching, repeated start, multi-byte burst transfers, or multi-master arbitration. These are natural next steps (see [Roadmap](#roadmap)).

### Testbench: `tb_i2c`

`I2C_TB.v` instantiates `i2c_master` (with `CLK_DIV = 4`) and drives `start`, `rw`, `addr`, and `tx_byte` to exercise a write transaction against the slave model, observing `busy`/`done` and the resulting `sda`/`scl` waveforms (see `I2c_waveform.png`).

---

## Simulation Instructions

All three protocols were verified in **ModelSim (Intel FPGA Starter Edition 10.5b)**.

1. Launch ModelSim and create/open a project pointing at the relevant protocol folder.
2. Compile sources, e.g. for UART:
   ```tcl
   vlog UART_Shivansh/*.sv
   ```
   or for SPI / I2C:
   ```tcl
   vlog SPI_Communication/SPIverilog_code/*.v
   vlog I2C_Communication/*.v
   ```
3. Load the corresponding testbench:
   ```tcl
   vsim work.DuplexTest      # UART
   vsim work.spi_top_tb      # SPI
   vsim work.tb_i2c          # I2C
   ```
4. Add signals and run:
   ```tcl
   add wave -position insertpoint sim:/<top_tb>/*
   run -all
   ```

---

## Roadmap

- [ ] Add clock stretching, repeated start, and multi-byte transfer support to I2C
- [ ] Add multi-master arbitration to I2C
- [ ] Add self-checking (assertion-based) scoreboards to all three testbenches instead of visual waveform inspection
- [ ] Add FPGA-level constraint files (pin assignments, clock config) for board bring-up
- [ ] Add a top-level regression script to run all three testbenches in one pass

---

## License

Specify your license here (e.g. MIT).

# SPI Memory Subsystem — SystemVerilog / Basys 3

A parameterized SPI memory subsystem written in SystemVerilog and implemented on the Digilent Basys 3 FPGA.

The project implements a complete host-to-memory communication path consisting of an SPI host controller, SPI master, multiple SPI slaves, and per-slave memory controllers. Internal communication uses AXI4-Stream-style interfaces, while the physical SPI interface supports all four CPOL/CPHA modes and continuous multi-word transactions.

The complete subsystem has been verified using self-checking SystemVerilog testbenches, synthesized and implemented in AMD Vivado, analyzed using post-implementation static timing analysis, and validated on Basys 3 hardware.

## Architecture

```text
                         100 MHz System Clock
                                │
                                ▼
                    ┌───────────────────────┐
                    │  SPI Host Controller  │
                    └───────────┬───────────┘
                                │ AXI4-Stream
                                ▼
                    ┌───────────────────────┐
                    │      SPI Master       │
                    └───────────┬───────────┘
                                │
                       Physical SPI Bus
                  SCLK / MOSI / MISO / CS_n
                                │
              ┌─────────────────┼─────────────────┐
              ▼                 ▼                 ▼
        ┌───────────┐     ┌───────────┐     ┌───────────┐
        │ SPI Slave │     │ SPI Slave │ ... │ SPI Slave │
        └─────┬─────┘     └─────┬─────┘     └─────┬─────┘
              │                  │                 │
         AXI4-Stream        AXI4-Stream       AXI4-Stream
              │                  │                 │
              ▼                  ▼                 ▼
        ┌───────────┐     ┌───────────┐     ┌───────────┐
        │  Memory   │     │  Memory   │ ... │  Memory   │
        │Controller │     │Controller │     │Controller │
        └─────┬─────┘     └─────┬─────┘     └─────┬─────┘
              ▼                  ▼                 ▼
            Memory             Memory            Memory
```

The host controller converts user requests into a six-word SPI transaction. The SPI master communicates with the selected slave, which transfers received requests to its memory controller. Responses propagate back through the slave and master to the host controller.

## Features

### SPI Master

- Parameterized data width
- Parameterized system and SPI clock frequencies
- Runtime CPOL/CPHA selection
- Support for all four SPI modes
- Multiple slave-select outputs
- Full-duplex MOSI/MISO communication
- MSB-first transfers
- Continuous multi-word transactions with `CS_n` held active
- AXI4-Stream transmit and receive interfaces
- `TLAST`-controlled transaction termination
- `TDEST`-based slave selection
- `TUSER`-based SPI mode selection
- Receive backpressure handling

### SPI Slave

- Parameterized data width
- Configurable CPOL and CPHA
- Support for all four SPI modes
- Full-duplex MOSI/MISO communication
- Continuous multi-word transactions
- AXI4-Stream request and response interfaces
- Data transfer between SPI-clock and system-clock logic
- Buffered controller responses for MISO transmission
- Dummy transmit data when no response is available

### Host and Memory Controllers

- READ and WRITE commands
- Multiple independent slave destinations
- Independent memory associated with each SPI slave
- Address-valid tracking for unwritten locations
- Invalid-read detection
- Write acknowledgement
- Returned transaction status
- Fixed-length six-word transaction protocol

## AXI4-Stream Interfaces

AXI4-Stream-style interfaces decouple the SPI transport layer from the host and memory controllers.

### Host to SPI Master

```text
Host Controller ──AXIS TX──► SPI Master
Host Controller ◄─AXIS RX── SPI Master
```

The transmit interface uses:

- `TDATA` — MOSI word
- `TVALID/TREADY` — word handshake
- `TLAST` — final word of the SPI transaction
- `TDEST` — slave selection
- `TUSER` — CPOL/CPHA selection

The receive interface returns the corresponding MISO words to the host controller.

### SPI Slave to Memory Controller

```text
SPI Slave ──request──► Memory Controller
SPI Slave ◄─response── Memory Controller
```

Received SPI words are transferred to the memory controller in the system-clock domain. Controller responses are transferred back to the SPI transmit datapath before being serialized onto MISO.

## Memory Protocol

Memory operations use a fixed six-word SPI transaction.

| Word | MOSI | MISO |
|---:|---|---|
| 1 | Opcode | Dummy |
| 2 | Address | Dummy |
| 3 | Write data / Read dummy | Dummy |
| 4 | Turnaround dummy | Dummy |
| 5 | Dummy | Validity |
| 6 | Dummy | Response |

### READ

A READ transaction provides an address and returns:

- A validity indication identifying whether the address has previously been written
- The stored memory value for a valid address

Reading an unwritten address returns an invalid status.

### WRITE

A WRITE transaction provides an address and data value. The memory controller stores the data, marks the address as valid, and returns a successful write response.

The turnaround phase provides time for request processing and transfer of the response back toward the SPI transmit datapath while `CS_n` remains asserted for the complete transaction.

## Clocking and Clock-Domain Transfer

The Basys 3 implementation uses:

- **System clock (`ACLK`)** — 100 MHz
- **SPI clock (`SCLK`)** — 10 MHz

`SCLK` is generated by the SPI master from the system clock.

The SPI slave contains logic operating on both clock domains. Control signals are synchronized between domains, while associated multi-bit data is held stable during transfer.

The generated SPI clock is explicitly constrained in Vivado, allowing timing paths between the SPI and system-clock domains to be analyzed during static timing analysis.

## Verification

The subsystem is verified using self-checking SystemVerilog testbenches in XSim.

System-level verification exercises the complete transaction path:

```text
Host Controller
      │
      ▼
 SPI Master
      │
      ▼
  SPI Slave
      │
      ▼
Memory Controller
      │
      ▼
  SPI Slave
      │
      ▼
 SPI Master
      │
      ▼
Host Controller
```

Tested functionality includes:

- All four CPOL/CPHA configurations
- Multiple SPI slave destinations
- READ transactions
- WRITE transactions
- Read-after-write verification
- Reads from unwritten addresses
- Validity/status responses
- Multi-word SPI transactions
- AXI4-Stream handshakes
- Runtime destination selection
- Runtime SPI-mode selection
- End-to-end data and response checking

Individual modules and subsystem behavior were also tested during development before integration into the complete system.

## Static Timing Analysis

Post-implementation static timing analysis was performed using AMD Vivado.

Timing analysis included:

- 100 MHz primary system-clock constraint
- 10 MHz generated SPI-clock constraint
- Setup timing analysis
- Hold timing analysis
- Intra-clock and inter-clock path analysis
- Clock interaction analysis
- Clock-domain crossing analysis
- Critical-path inspection
- Constraint coverage checking

The implemented design completed timing analysis with:

- No setup timing violations
- No hold timing violations
- No unconstrained internal endpoints

A detailed critical-path inspection was also performed to examine logic delay, routing delay, clock skew, clock uncertainty, and resulting timing slack.

## Hardware Validation

The completed design was synthesized, placed, routed, and programmed onto a Digilent Basys 3 FPGA development board.

Hardware testing verified READ and WRITE memory transactions through the complete communication path.

The implementation was tested across all four SPI modes:

| Mode | CPOL | CPHA |
|---|---:|---:|
| 0 | 0 | 0 |
| 1 | 0 | 1 |
| 2 | 1 | 0 |
| 3 | 1 | 1 |

Different slave instances use different SPI modes. The host provides the selected slave's mode to the SPI master at the beginning of each transaction.

The Basys 3 user interface provides control and visibility for:

- Memory address
- Write data
- Read data
- READ/WRITE operation selection
- SPI slave selection
- Selected CPOL/CPHA mode
- Transaction status
- Seven-segment display output

## Parameters

| Parameter | Description |
|---|---|
| `DATA_WIDTH` | Number of bits per SPI word |
| `NUM_SLAVES` / `NUM_DESTINATIONS` | Number of SPI slave destinations |
| `CLK_FREQ` | System-clock frequency |
| `SPI_FREQ` | SPI-clock frequency |
| `CPOL` | SPI clock polarity |
| `CPHA` | SPI clock phase |

Parameters apply to the modules where relevant.

## Project Status

**Complete and validated on hardware.**

- [x] SPI master RTL
- [x] SPI slave RTL
- [x] SPI host controller
- [x] SPI memory controller
- [x] AXI4-Stream internal interfaces
- [x] Multi-slave operation
- [x] All four SPI modes
- [x] Six-word memory protocol
- [x] Clock-domain transfer logic
- [x] Self-checking SystemVerilog verification
- [x] Vivado synthesis and implementation
- [x] Generated-clock timing constraints
- [x] Post-implementation static timing analysis
- [x] Clock-domain crossing analysis
- [x] Basys 3 hardware validation

## Tools

- SystemVerilog
- AMD Vivado
- XSim
- Digilent Basys 3
- Xilinx Artix-7 FPGA

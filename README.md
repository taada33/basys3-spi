# SPI Communication System — SystemVerilog / Basys 3

A parameterized SPI communication system written in SystemVerilog and targeting the Digilent Basys 3 FPGA.

The project implements SPI master and slave RTL with support for all four SPI modes, multi-word transactions, AXI4-Stream interfaces, and clock-domain crossing between the SPI and system-clock domains. A class-based SystemVerilog verification environment is being developed alongside the RTL.

The long-term goal is a complete memory-access subsystem in which a host controller communicates with a memory controller over SPI.

## Architecture

```text
┌───────────────────────┐
│  SPI Host Controller  │
└───────────┬───────────┘
            │ AXI4-Stream
            ▼
┌───────────────────────┐
│      SPI Master       │
└───────────┬───────────┘
            │
            │ SPI
            │ SCLK / MOSI / MISO / CS_n
            ▼
┌───────────────────────┐
│       SPI Slave       │
└───────────┬───────────┘
            │ AXI4-Stream
            ▼
┌───────────────────────┐
│ SPI Memory Controller │
└───────────┬───────────┘
            │
            ▼
          Memory
```

The SPI host and memory controllers are currently under development.

## Features

### SPI Master

- Parameterized data width
- Parameterized system and SPI clock frequencies
- Configurable CPOL and CPHA
- Support for all four SPI modes
- Multiple slave-select outputs
- Full-duplex MOSI/MISO communication
- MSB-first transfers
- Continuous multi-word transfers with CS held active across a burst
- AXI4-Stream transmit and receive interfaces
- `TLAST`-controlled burst termination
- `TDEST`-based slave selection
- AXI4-Stream receive backpressure handling

### SPI Slave

- Parameterized data width
- Configurable CPOL and CPHA
- Support for all four SPI modes
- Full-duplex MOSI/MISO communication
- Continuous multi-word transfers
- AXI4-Stream request and response interfaces
- Clock-domain crossing between the SPI clock and AXI system-clock domains
- Dummy transmit data when no response is available
- Buffered response transfer into the SPI transmit datapath

## AXI4-Stream Interfaces

AXI4-Stream is used internally to decouple the SPI transport layer from the higher-level controllers.

### Master

The SPI master uses two streams:

```text
Host Controller ──AXIS TX──► SPI Master
Host Controller ◄─AXIS RX── SPI Master
```

On the transmit stream:

- `TDATA` contains the MOSI word.
- `TVALID/TREADY` control transfer of each word.
- `TLAST` identifies the final word of an SPI burst.
- `TDEST` selects the SPI slave.

The receive stream returns the corresponding MISO words.

### Slave

The SPI slave exposes request and response streams:

```text
SPI Slave ──request──► Memory Controller
SPI Slave ◄─response── Memory Controller
```

Received MOSI words are transferred into the system-clock domain as requests. Response words cross back into the SCLK domain before being serialized onto MISO.

## Clock-Domain Crossing

The SPI slave operates across two clock domains:

- `SCLK` — SPI protocol and shift logic
- `ACLK` — AXI4-Stream/controller logic

Control signals are synchronized between the domains, while associated data is held stable during transfer.

The current implementation is designed around a system clock significantly faster than the SPI word rate. CDC behavior and timing will be validated as part of system-level verification.

## Planned Memory Protocol

The planned controller layer uses fixed-length SPI bursts for memory operations.

### Read

| Word | MOSI | MISO |
|---|---|---|
| 0 | READ command | Dummy |
| 1 | Address | Dummy |
| 2 | Dummy | Dummy |
| 3 | Dummy | Read data |

### Write

| Word | MOSI | MISO |
|---|---|---|
| 0 | WRITE command | Dummy |
| 1 | Address | Dummy |
| 2 | Write data | Dummy |
| 3 | Dummy | Status |

The turnaround word provides time for request processing and response clock-domain crossing while keeping the SPI interface continuously clocked.

## Verification

A class-based SystemVerilog verification environment is under development.

Current verification components include:

- Randomized stimulus transactions
- Generator
- SPI driver
- SPI monitor
- Directed and randomized transaction support
- Abort injection using reset or chip-select
- Parameterized CPOL/CPHA handling

Planned verification work includes:

- Scoreboard
- Functional coverage
- AXI4-Stream backpressure testing
- CDC timing scenarios
- All four CPOL/CPHA configurations
- Master-only verification
- Slave-only verification
- Master/slave integration verification
- Controller-to-controller system verification

## Parameters

| Parameter | Description |
|---|---|
| `DATA_WIDTH` | Number of bits per SPI word |
| `NUM_SLAVES` | Number of SPI slave-select outputs |
| `CLK_FREQ` | System clock frequency |
| `SPI_FREQ` | SPI clock frequency |
| `CPOL` | SPI clock polarity |
| `CPHA` | SPI clock phase |

Parameters apply to the modules where relevant.

## Supported SPI Modes

| Mode | CPOL | CPHA |
|---|---:|---:|
| 0 | 0 | 0 |
| 1 | 0 | 1 |
| 2 | 1 | 0 |
| 3 | 1 | 1 |

## Project Status

### Implemented

- SPI master RTL
- SPI slave RTL
- All four CPOL/CPHA modes
- Multi-word SPI bursts
- AXI4-Stream interface
- SPI slave CDC logic
- Initial class-based verification infrastructure

### In Progress

- SPI host controller
- SPI memory controller
- Scoreboard and functional coverage
- Integrated subsystem verification

### Planned

- Memory subsystem
- Complete end-to-end verification
- Basys 3 hardware demonstration
- Timing and CDC analysis
- Scripted simulation/build flow

## Tools

- SystemVerilog
- AMD Vivado
- XSim
- Digilent Basys 3 / Xilinx Artix-7

# SPI Master (SystemVerilog)

A parameterized SPI Master controller written in SystemVerilog for the Digilent Basys 3 FPGA. The design supports configurable clock polarity (CPOL), clock phase (CPHA), clock frequency, data width, and multiple slave devices.

## Features

- Parameterized data width
- Parameterized SPI clock frequency
- Configurable clock polarity (CPOL)
- Configurable clock phase (CPHA)
- Support for multiple slave devices
- Full-duplex SPI communication (simultaneous transmit and receive)
- MSB-first data transfer
- Busy and transaction complete status signals
- Synthesizable SystemVerilog RTL

## Parameters

| Parameter | Description |
|-----------|-------------|
| `DATA_WIDTH` | Number of bits per SPI transaction |
| `NUM_SLAVES` | Number of chip-select outputs |
| `CLK_FREQ` | FPGA system clock frequency |
| `SPI_FREQ` | Desired SPI clock frequency |
| `CPOL` | SPI clock polarity |
| `CPHA` | SPI clock phase |

## Project Structure

```text

SPI_Master.srcs/
├── sources_1/
│   ├── spi_master.sv

```

## Supported SPI Modes

| Mode | CPOL | CPHA |
|------|:----:|:----:|
| 0 | 0 | 0 |
| 1 | 0 | 1 |
| 2 | 1 | 0 |
| 3 | 1 | 1 |


## Future Work

- SPI Slave implementation
- Self-checking SystemVerilog testbench
- Top-level hardware demonstration
- Continuous multi-byte transfers
- Support for dummy cycles

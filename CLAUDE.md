# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands
- Basic simulation: `python3 sim.py`
- Generate waveforms: `python3 sim.py --wave` or `python3 sim.py -w`
- View waveforms with Surfer: `python3 sim.py --wave --gui` or `python3 sim.py -w -g`
- Debug mode: `python3 sim.py --debug` or `python3 sim.py -d`
- Clean build artifacts: `python3 sim.py --clean` or `python3 sim.py -c`

## Environment Setup
- Create Python virtual environment: `python3 -m venv .venv`
- Activate virtual environment: `source .venv/bin/activate`
- Install dependencies: `pip install -e .`

## Code Style Guidelines
- SystemVerilog files (.sv) for RTL, header files (.svh) for macros
- Parameters: UPPER_CASE
- I/O signals: snake_case with _i/_o suffixes (clk_i, rst_i, tdata_o)
- Internal signals: snake_case with _w/_r suffixes (tdata_r, valid_w)
- Types: snake_case with _t suffix (packet_header_t)
- 4-space indentation
- Module structure: parameters, I/O ports, local params, internal signals, logic
- Aligned port and parameter declarations
- Include guards in all .svh files
- Package files for type definitions and utility functions
- Only use comments where the code is not clear by itself.
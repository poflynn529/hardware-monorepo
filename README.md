# hardware-monorepo

Repository for FPGA hardware designs with (mostly) cocotb and verilator-based simulation.

## Setup

### Dependancies

- [Verilator](https://verilator.org/guide/latest/install.html)
- [Surfer](https://surfer-project.org/)

### Virtual Environment

Create and activate a Python virtual environment:

```bash
# Create virtual environment:
python3 -m venv .venv

# Activate virtual environment:
source .venv/bin/activate

# Install dependencies:
pip install -e .
```

## Running Simulations

```bash
#Basic simulation:
python3 sim.py

# Generate waveforms:
python3 sim.py --wave

# View waveforms with Surfer:
python3 sim.py --wave --gui

# Enable debug mode:
python3 sim.py --debug

# Clean build artifacts:
python3 sim.py --clean
```

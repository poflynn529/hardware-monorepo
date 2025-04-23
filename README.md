# hardware-monorepo

Repository for FPGA hardware designs with cocotb and verilator-based simulation.

## Setup

### Dependancies

- Verilator [(Link)[https://verilator.org/guide/latest/install.html]]
- Surfer [(Link)[https://surfer-project.org/]]

### Virtual Environment

Create and activate a Python virtual environment:

```bash
# Create virtual environment
python3 -m venv .venv

# Activate virtual environment (Linux/macOS)
source .venv/bin/activate

# Install dependencies
pip install -e .
```

## Running Simulations

Basic simulation:
```bash
python3 sim.py
```

Generate waveforms:
```bash
python3 sim.py --wave
```

View waveforms with Surfer:
```bash
python3 sim.py --wave --gui
```

Enable debug mode:
```bash
python3 sim.py --debug
```

Clean build artifacts:
```bash
python3 sim.py --clean
```
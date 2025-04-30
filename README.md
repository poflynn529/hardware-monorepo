# hardware-monorepo

My personal repository for hardware designs, mostly targetting Xilinx FPGAs. Build system is FuseSoC and TBs are mostly cocotb.

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

## Notes

List of the packages I had to install for this project (May differ on your system):

DNF / APT installable packages:
```
verilator
gcc-c++
python3.13-devel
```

Manual Downloads:
```
surfer
```

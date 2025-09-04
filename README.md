# hardware-monorepo

My personal repository for hardware designs, mostly targetting Xilinx FPGAs. Build system is FuseSoC and TBs are mostly cocotb.

## Setup

### Dependancies

- [Verilator](https://verilator.org/guide/latest/install.html)
- [Surfer](https://surfer-project.org/)
- [uv](https://github.com/astral-sh/uv)

### Virtual Environment

Create and activate a Python virtual environment:

```bash
# Create virtual environment:
uv venv
```

## Running Simulations

```bash
# Run cocotb and verilator:
make -f common_hdl_lib/axi/tb/Makefile

# View the dump.fst output file:
surfer dump.fst
```

## Notes

List of the packages I had to install for this project that `dnf` didn't pick up (May differ on your system):

```
gcc-c++
python3.13-devel
zlib-devel
```

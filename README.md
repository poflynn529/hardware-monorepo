# hardware-monorepo

My personal repository for hardware related projects. I mostly use this for playing around with new tools and quick evaluations.

## Setup

### Dependancies

- [Verilator](https://verilator.org/guide/latest/install.html)
- [Surfer](https://surfer-project.org/)
- [uv](https://github.com/astral-sh/uv)
- [Buck2](https://buck2.build/)

### Virtual Environment

Create and activate a Python virtual environment:

```bash
# Build the virtual environment:
uv sync
```

## Running Simulations

```bash
# Run cocotb and verilator:
buck2 build //common_hdl_lib/axi/tb:axi4s_skid_buffer_test

# View the dump.fst output file:
surfer dump.fst
```

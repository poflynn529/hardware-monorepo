## Build System

This repo uses Buck2 as its build system.
Python packages are provided by uv.

- Build a target: `buck2 build //path/to:target`
- Run a test: `buck2 build //path/to/tb:test_name`
- Clean all build artifacts: `buck2 clean`

## Style Guidelines

- Only use comments where the code is not clear by itself.

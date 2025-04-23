#!/usr/bin/env python3
"""
Simulation controller for hardware-monorepo using cocotb and verilator.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# Project structure constants
PROJECT_ROOT = Path(__file__).resolve().parent
FPGASHARK_DIR = PROJECT_ROOT / "fpgashark"
COMMON_LIB_DIR = PROJECT_ROOT / "common_lib"
PACKET_BUFFER_DIR = FPGASHARK_DIR / "packet_buffer"

# Verilator settings
VERILATOR_FLAGS = [
    "--trace",          # Generate VCD trace
    "--trace-fst",      # Generate FST trace (smaller/faster than VCD)
    "--trace-structs",  # Include struct definitions in trace
    "--trace-depth", "0",  # Unlimited trace depth
    "--timing",         # Include timing models
    "--assert",         # Enable assertions
    "--coverage",       # Enable coverage
    "--language 1800-2012",  # Use SystemVerilog-2012
    "-Wall",            # Enable all warnings
    "-Wno-fatal",       # Continue after warnings
]

def setup_env():
    """Prepare the environment variables for simulation."""
    os.environ["PYTHONPATH"] = str(PROJECT_ROOT)
    os.environ["SIM"] = "verilator"
    os.environ["COCOTB_REDUCED_LOG_FMT"] = "1"
    os.environ["COCOTB_LOG_LEVEL"] = "INFO"

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Hardware simulation runner")
    parser.add_argument("--top", "-t", default="packet_buffer",
                        help="Top-level module to simulate")
    parser.add_argument("--wave", "-w", action="store_true", 
                        help="Generate waveforms")
    parser.add_argument("--debug", "-d", action="store_true", 
                        help="Enable debug mode with additional logging")
    parser.add_argument("--gui", "-g", action="store_true", 
                        help="Open waveform viewer after simulation")
    parser.add_argument("--clean", "-c", action="store_true", 
                        help="Clean build artifacts before running")
    
    return parser.parse_args()

def get_verilog_files(top_module):
    """Collect SystemVerilog files for compilation."""
    if top_module == "packet_buffer":
        # Collect all the SystemVerilog files needed for packet_buffer
        files = [
            # Common libraries
            COMMON_LIB_DIR / "utils" / "utils.sv",
            COMMON_LIB_DIR / "utils" / "macros.svh",
            COMMON_LIB_DIR / "pcap" / "pcap_pkg.sv",
            COMMON_LIB_DIR / "pcap" / "pcap2axi4s_pkg.sv",
            
            # Packet buffer package
            PACKET_BUFFER_DIR / "pkg" / "packet_buffer_pkg.sv",
            
            # Core implementation files
            PACKET_BUFFER_DIR / "src" / "vector_muxcy.sv",
            PACKET_BUFFER_DIR / "src" / "fifo36e2_wrapper.sv",
            PACKET_BUFFER_DIR / "src" / "axi4s_skid_buffer.sv",
            PACKET_BUFFER_DIR / "src" / "packet_buffer_write_controller.sv",
            PACKET_BUFFER_DIR / "src" / "packet_buffer.sv",
            
            # Xilinx primitives (for simulation only)
            FPGASHARK_DIR / "xilinx_bram.sv",
        ]
        
        includes = [
            "-I" + str(COMMON_LIB_DIR / "utils"),
            "-I" + str(PACKET_BUFFER_DIR / "pkg"),
        ]
        
        return files, includes
    
    else:
        print(f"Error: Unsupported top module '{top_module}'")
        sys.exit(1)

def verilator_compile(args, verilog_files, includes):
    """Compile the design using Verilator."""
    build_dir = PROJECT_ROOT / "build" / args.top
    build_dir.mkdir(parents=True, exist_ok=True)
    
    filelist = build_dir / "filelist.f"
    with open(filelist, "w") as f:
        for vfile in verilog_files:
            f.write(f"{vfile}\n")
    
    cmd = ["verilator"]
    cmd.extend(VERILATOR_FLAGS)
    
    cmd.extend(includes)
    
    if args.debug:
        cmd.append("--debug")

    cmd.extend([
        "--build",
        "--exe",
        "--Mdir",       str(build_dir),
        "-o",           str(build_dir / args.top),
        "-f",           str(filelist),
        "--top-module", args.top,
        "--build-jobs", "8",
    ])
    
    # Add cocotb VPI library
    vpi_dir = subprocess.check_output(
        ["python3", "-c", "import cocotb; print(cocotb.__path__[0])"],
        text=True
    ).strip()
    
    cmd.extend([
        f"+define+COCOTB_SIM=1",
        f"-LDFLAGS '-Wl,-rpath,{vpi_dir}/share/lib/ -L{vpi_dir}/share/lib/ -lcocotbvpi_verilator'",
    ])
    
    print("Compiling design with Verilator...")
    print(" ".join(cmd))
    
    try:
        subprocess.run(cmd, check=True)
        return build_dir / args.top
    except subprocess.CalledProcessError as e:
        print(f"Compilation failed: {e}")
        sys.exit(1)

def run_cocotb(args, executable, build_dir):
    """Run the simulation with cocotb."""
    if args.debug:
        os.environ["COCOTB_LOG_LEVEL"] = "DEBUG"
    
    if args.wave:
        os.environ["WAVES"] = "1"
    
    test_module = f"fpgashark.{args.top.lower()}.tb"
    cmd = [
        str(executable),
        f"+COCOTB_MODULE={test_module}",
    ]
    
    if args.wave:
        fst_file = build_dir / f"{args.top}.fst"
        cmd.append(f"+COCOTB_FST_FILE={fst_file}")
    
    print("Running simulation...")
    try:
        subprocess.run(cmd, check=True)
        
        if args.wave and args.gui:
            open_waveform_viewer(args, build_dir)
    
    except subprocess.CalledProcessError as e:
        print(f"Simulation failed: {e}")
        sys.exit(1)

def open_waveform_viewer(args, build_dir):
    """Open the waveform viewer."""
    wave_file = f"{args.top}.fst"
    
    if not wave_file.exists():
        print(f"Error: Waveform file {wave_file} not found.")
        return
    
    print(f"Opening waveform with Surfer: {wave_file}")
    subprocess.Popen(["surfer", str(wave_file)])

def clean_build(args):
    """Clean build artifacts."""
    build_dir = PROJECT_ROOT / "build" / args.top
    if build_dir.exists():
        print(f"Cleaning build directory: {build_dir}")
        subprocess.run(["rm", "-rf", str(build_dir)])

def main():
    """Main entry point."""
    args = parse_args()
    setup_env()
    
    if args.clean:
        clean_build(args)
    
    verilog_files, includes = get_verilog_files(args.top)
    
    executable = verilator_compile(args, verilog_files, includes)
    
    if args.top == "packet_buffer":
        cocotb_test_dir = PACKET_BUFFER_DIR / "tb"
        cocotb_test_dir.mkdir(parents=True, exist_ok=True)
    
    build_dir = PROJECT_ROOT / "build" / args.top
    run_cocotb(args, executable, build_dir)

if __name__ == "__main__":
    main()
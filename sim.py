#!/usr/bin/env python3
"""
Simulation controller for hardware-monorepo using FuseSoC
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# Project structure constants
PROJECT_ROOT = Path(__file__).resolve().parent

def setup_env():
    """Prepare the environment variables for simulation."""
    os.environ["PYTHONPATH"] = str(PROJECT_ROOT)
    os.environ["COCOTB_REDUCED_LOG_FMT"] = "1"
    os.environ["COCOTB_LOG_LEVEL"] = "INFO"

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="FuseSoC-based hardware simulation runner")
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

def run_fusesoc(args):
    """Run FuseSoC with appropriate arguments."""
    cmd = ["fusesoc", "--cores-root", str(PROJECT_ROOT), "run"]
    
    # Set target options based on top module
    if args.top == "packet_buffer":
        target = "fpgashark:packet_buffer:tb"
        fusesoc_target = "verilator_sim"
    else:
        print(f"Error: Unsupported top module '{args.top}'")
        sys.exit(1)
    
    cmd.extend(["--target", fusesoc_target])
    
    if args.wave:
        cmd.extend(["--parameter", "waves=true"])
    
    if args.debug:
        os.environ["COCOTB_LOG_LEVEL"] = "DEBUG"
        cmd.extend(["--log-level", "debug"])
    
    # Add the target core
    cmd.append(target)
    
    # Clean if requested
    if args.clean:
        clean_cmd = ["fusesoc", "--cores-root", str(PROJECT_ROOT), "run", 
                    "--target", fusesoc_target, "--clean", target]
        print(f"Cleaning build artifacts: {' '.join(clean_cmd)}")
        subprocess.run(clean_cmd, check=True)
    
    # Run FuseSoC
    print(f"Running simulation: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, check=True)
        
        # Find the generated waveform
        if args.wave and args.gui:
            # FuseSoC build directory structure
            build_dir = PROJECT_ROOT / "build" / target.replace(":", "_") / fusesoc_target
            fst_file = list(build_dir.glob("*.fst"))
            
            if fst_file:
                print(f"Opening waveform with Surfer: {fst_file[0]}")
                subprocess.Popen(["surfer", str(fst_file[0])])
            else:
                print("No waveform file found")
        
        return result.returncode
    except subprocess.CalledProcessError as e:
        print(f"Simulation failed: {e}")
        return e.returncode

def main():
    """Main entry point."""
    args = parse_args()
    setup_env()
    
    return run_fusesoc(args)

if __name__ == "__main__":
    sys.exit(main())
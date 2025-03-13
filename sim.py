#!/usr/bin/env python3
"""
Simple script to run XSim for SystemVerilog simulation
"""

import subprocess
import argparse
import os

def run_simulation(generate_wave=False):
    # Step 1: Compile the SystemVerilog files
    print("Compiling SystemVerilog files...")
    subprocess.run(["xvlog", "-sv", "counter.sv", "counter_tb.sv", "-nolog"], check=True)
    
    # Step 2: Elaborate the design
    print("Elaborating design...")
    if generate_wave:
        # Add debug flag for waveform capture
        subprocess.run(["xelab", "counter_tb", "-s", "counter_sim", "-debug", "all", "-nolog"], check=True)
    else:
        subprocess.run(["xelab", "counter_tb", "-s", "counter_sim"], check=True)
    
    # Step 3: Run the simulation
    print("Running simulation...")
    if generate_wave:
        # Create a simple Tcl script for waveform capture
        with open("wave.tcl", "w") as f:
            f.write("open_vcd waveform.vcd\n")  # Open VCD file
            f.write("log_vcd [get_objects -r *]\n")  # Log all signals to VCD
            f.write("run all\n")  # Run simulation
            f.write("close_vcd\n")  # Close VCD file
            f.write("quit\n")  # Exit XSim
        
        # Run with waveform capture
        subprocess.run(["xsim", "counter_sim", "-tclbatch", "wave.tcl"], check=True)
    else:
        # Run without waveform capture
        subprocess.run(["xsim", "counter_sim", "-runall"], check=True)

def open_waveform(waveform_file):
    subprocess.Popen(["surfer", waveform_file], shell=False)

def main():
    parser = argparse.ArgumentParser(
        description="Run XSim simulation for SystemVerilog designs"
    )
    parser.add_argument(
        "-w", "--wave", 
        action="store_true",
        help="Generate waveform files and open in Surfer"
    )
    
    args = parser.parse_args()
    
    # Run the simulation
    run_simulation(args.wave)
    
    # If wave flag is set, open waveform
    open_waveform("waveform.vcd")

if __name__ == "__main__":
    main()

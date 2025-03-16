#!/usr/bin/env python3
# Simple script to run XSim for SystemVerilog simulation

import subprocess
import argparse
import logging

XILINX_PATH = "/tools/Xilinx/Vivado/2024.2"
UNISIM_VERILOG_PATH = f"{XILINX_PATH}/data/verilog/src"
UNISIM_INCLUDE_PATHS = [
    f"{UNISIM_VERILOG_PATH}",
    f"{UNISIM_VERILOG_PATH}/unisims"
]

def run_simulation(generate_wave=False):
    # Set environment variables to suppress log files
    env = os.environ.copy()
    env["XILINX_SUPPRESS_LOGS"] = "1"
    
    ### Compilation ###
    sv_files = ["fpgashark/xilinx_bram.sv", "fpgashark/xilinx_bram_tb.sv"]
    
    logging.info(f"Compiling SystemVerilog files: {', '.join(sv_files)}")
    
    xvlog_cmd = [
        "xvlog", 
        "-sv",
        "-nolog",
        "-nojournal",
        "-notimingchecks",
        f"{UNISIM_VERILOG_PATH}/unisim_comp.v"
        ]

    for path in UNISIM_INCLUDE_PATHS:
        xvlog_cmd.extend(["-i", path])
    xvlog_cmd.extend(sv_files)
    
    subprocess.run(xvlog_cmd, check=True, env=env)
    
    ### Elaboration ###
    logging.info(f"Elaborating design...")
    xelab_cmd = [
        "xelab", 
        "xilinx_bram_tb",
        "-s",
        "sim",
        "-L",
        "unisim",
        "-nolog",
        "-nojournal",
        ]
    
    if generate_wave:
        xelab_cmd.extend(["-debug", "all"])
    
    subprocess.run(xelab_cmd, check=True, env=env)
    
    ### Simulation ###
    logging.info(f"Running simulation...")

    xsim_cmd = ["xsim", "sim", "-nolog", "-nojournal"]
    
    if generate_wave:
        xsim_cmd.extend(["-tclbatch", "wave.tcl"])
    else:
        xsim_cmd.append("-runall")
    
    subprocess.run(xsim_cmd, check=True, env=env)

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
    
    run_simulation(args.wave)
    
    if args.wave:
        open_waveform("waveform.vcd")

if __name__ == "__main__":
    main()

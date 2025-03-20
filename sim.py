#!/usr/bin/env python3
# Simple script to run XSim for SystemVerilog simulation

import subprocess
import argparse
import logging
import os

XILINX_PATH = "/tools/Xilinx/Vivado/2024.2"
UNISIM_VERILOG_PATH = f"{XILINX_PATH}/data/verilog/src"
UNISIM_INCLUDE_PATHS = [
    f"{UNISIM_VERILOG_PATH}",
    f"{UNISIM_VERILOG_PATH}/unisims"
]

def run_simulation(generate_wave=False):
    env = os.environ.copy()
    env["XILINX_SUPPRESS_LOGS"] = "1"
    
    ### Compilation ###
    
    # top_level = "xilinx_bram_tb"
    # sv_files = [
    #     "fpgashark/xilinx_bram.sv",
    #     "fpgashark/xilinx_bram_tb.sv"
    #     ]
    
    top_level = "packet_buffer_tb_top"
    sv_files = [
        "common/utils/utils.svh",
        "common/pcap/pcap2axi4s.svh",
        "fpgashark/packet_buffer/src/fifo36e2_wrapper.sv",
        "fpgashark/packet_buffer/src/packet_buffer.sv",
        "fpgashark/packet_buffer/tb/packet_buffer_tb_top.sv",
    ]
    
    logging.info(f"Compiling SystemVerilog files: {', '.join(sv_files)}")
    
    xvlog_cmd = [
        "xvlog", 
        "-sv",
        "-nolog",
        f"{UNISIM_VERILOG_PATH}/unisim_comp.v"
        ]

    for path in UNISIM_INCLUDE_PATHS:
        xvlog_cmd.extend(["-i", path])
    for path in sv_files:
        xvlog_cmd.extend(["-i", path])
    
    subprocess.run(xvlog_cmd, check=True, env=env)
    
    ### Elaboration ###
    logging.info(f"Elaborating design...")
    xelab_cmd = [
        "xelab", 
        top_level,
        "-s",
        top_level,
        "-L",
        "unisim",
        "-nolog",
        ]
    
    if generate_wave:
        xelab_cmd.extend(["-debug", "all"])
    
    subprocess.run(xelab_cmd, check=True, env=env)
    
    ### Simulation ###
    logging.info(f"Running simulation...")

    xsim_cmd = [
        "xsim", 
        top_level, 
        "-nolog",
        ]
    
    if generate_wave:
        xsim_cmd.extend(["-tclbatch", "wave.tcl"])
    else:
        xsim_cmd.append("-runall")
    
    subprocess.run(xsim_cmd, check=True, env=env)

def open_waveform(waveform_file):
    subprocess.Popen(["surfer", waveform_file], shell=False)

def cleanup():
    subprocess.run(["rm", "xelab.pb", "xvlog.pb", "xsim.jou"])

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
    cleanup()
    
    if args.wave:
        open_waveform("waveform.vcd")

if __name__ == "__main__":
    main()

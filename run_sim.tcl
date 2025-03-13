# Tcl script for Vivado simulation
# Create a new project in memory
create_project -in_memory -part xc7a35tcpg236-1

# Add the SystemVerilog files
add_files -norecurse {counter.sv counter_tb.sv}
update_compile_order -fileset sources_1

# Set counter_tb as the top module for simulation
set_property top counter_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Set simulation options
set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

# Launch simulation
launch_simulation -simset sim_1 -mode behavioral

# Log all signals
log_wave -r /*

# Run the simulation
run 1000ns

# Save the waveform data to a file that can be viewed in Surfer
save_wave_config {waveform.wcfg}

# Close the simulation
close_sim

# Exit Vivado
quit 
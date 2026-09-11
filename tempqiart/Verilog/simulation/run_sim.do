
# Python supplies the portable project directory explicitly. GUI users who
# open BitSieve25Test.mpf already start in this directory, so pwd is the safe
# fallback. ModelSim 20.1's `info script` points at its internal Tcl launcher
# and therefore cannot be used to locate a .do file reliably.
if {[info exists ::env(BITSIEVE_SIMULATION_DIR)]} {
    # Do not call `file normalize` here. ModelSim 20.1 incorrectly resolves
    # Windows known-folder components such as "Documents" on some systems.
    cd $::env(BITSIEVE_SIMULATION_DIR)
}
if {(![info exists ::env(BITSIEVE_BATCH)] || $::env(BITSIEVE_BATCH) ne "1") &&
    ![file exists "BitSieve25Test.mpf"]} {
    error "Run run_sim.do from its simulation directory, or set BITSIEVE_SIMULATION_DIR."
}

# Clear the GUI transcript when a GUI is present. In command-line mode the
# .main widget does not exist, so ignore that cosmetic operation.
catch {.main clear}

# The GUI's out-of-date command queries a project-pane widget that does not
# exist in command-line mode. Compile the full project for automated batches;
# retain the faster out-of-date behaviour for ordinary GUI runs.
if {[info exists ::env(BITSIEVE_BATCH)] && $::env(BITSIEVE_BATCH) eq "1"} {
    if {![info exists ::env(BITSIEVE_SKIP_COMPILE)]} {
        project compileall
    }
} else {
    project compileoutofdate
}

# Start the simulation in whichever mode launched this script. Automated
# batches disable the very large VCD dump; ordinary GUI runs retain it.
set simulation_arguments {}
if {[info exists ::env(BITSIEVE_BATCH)] && $::env(BITSIEVE_BATCH) eq "1"} {
    lappend simulation_arguments +NO_VCD
    lappend simulation_arguments +QUIET_BATCH
}
if {[info exists ::env(BITSIEVE_MAX_ITER_OVERRIDE)]} {
    lappend simulation_arguments +MAX_ITER=$::env(BITSIEVE_MAX_ITER_OVERRIDE)
}
if {[info exists ::env(BITSIEVE_QUBO_CONSTANT_RAW)]} {
    lappend simulation_arguments +QUBO_CONSTANT_RAW=$::env(BITSIEVE_QUBO_CONSTANT_RAW)
}
if {[info exists ::env(BITSIEVE_QUBO_CONSTANT)]} {
    lappend simulation_arguments +QUBO_CONSTANT=$::env(BITSIEVE_QUBO_CONSTANT)
}
if {[info exists ::env(BITSIEVE_GLOBAL_MIN_RAW)]} {
    lappend simulation_arguments +GLOBAL_MIN_RAW=$::env(BITSIEVE_GLOBAL_MIN_RAW)
}
eval vsim work.tb_bit_sieve_engine_25 $simulation_arguments

# 1-bit control signals (Default Radix)
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/clk
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/rng_ADB_en
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/valid_hold_en
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/rng_US_en
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/ising_update_en
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/state_update_en
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/e_off_update_en
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/h_update_en
#
## Array/Energy Signals (Signed Decimal)
#add wave -position insertpoint -radix decimal sim:/tb_bit_sieve_engine_25/uut/uut/weights
#add wave -position insertpoint -radix decimal sim:/tb_bit_sieve_engine_25/uut/uut/delta_E_array
#
## Index Signal (Unsigned Decimal)
#add wave -position insertpoint -radix unsigned sim:/tb_bit_sieve_engine_25/uut/uut/winner_index
#
## Energy Signal (Signed Decimal)
#add wave -position insertpoint -radix decimal sim:/tb_bit_sieve_engine_25/uut/uut/Ising_Energy
#
## 1024-bit Wide State/Mask Signals (Hexadecimal)
#add wave -position insertpoint -radix hex sim:/tb_bit_sieve_engine_25/uut/uut/current_state_X
#add wave -position insertpoint -radix hex sim:/tb_bit_sieve_engine_25/uut/uut/valid_candidates
#add wave -position insertpoint -radix hex sim:/tb_bit_sieve_engine_25/uut/uut/tabu_mask
#add wave -position insertpoint -radix hex sim:/tb_bit_sieve_engine_25/uut/uut/valid_bits
#
## 1-bit Status Signal (Default Radix)
#add wave -position insertpoint sim:/tb_bit_sieve_engine_25/uut/uut/winner_found
#
## Energy Offset Signal (Signed Decimal)
#add wave -position insertpoint -radix decimal sim:/tb_bit_sieve_engine_25/uut/uut/current_E_off

run -all

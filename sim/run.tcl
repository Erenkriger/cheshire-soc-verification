#!/usr/bin/env tclsh
# ============================================================================
# run.tcl — Vivado xsim simulation script
# Usage:
#   vivado -mode batch -source run.tcl
#   vivado -mode batch -source run.tcl -tclargs <test_name> <verbosity>
#
# Examples:
#   vivado -mode batch -source run.tcl -tclargs soc_sanity_test UVM_LOW
#   vivado -mode batch -source run.tcl -tclargs soc_uart_loopback_test UVM_MEDIUM
# ============================================================================

# ── Defaults ──
set test_name  "soc_sanity_test"
set verbosity  "UVM_MEDIUM"
set sim_time   "1ms"

# ── Parse arguments ──
if { $argc >= 1 } { set test_name [lindex $argv 0] }
if { $argc >= 2 } { set verbosity [lindex $argv 1] }
if { $argc >= 3 } { set sim_time  [lindex $argv 2] }

puts "═══════════════════════════════════════════"
puts " SoC UVM — Vivado xsim Flow"
puts " Test:      $test_name"
puts " Verbosity: $verbosity"
puts " Sim Time:  $sim_time"
puts "═══════════════════════════════════════════"

# ── Step 1: Compile ──
puts "\n>>> Step 1: Compiling RTL + TB..."
exec xvlog -sv -f compile_sv.f -L uvm 2>@1

# ── Step 2: Elaborate ──
puts "\n>>> Step 2: Elaborating design..."
exec xelab tb_top -relax -s soc_sim_snapshot \
    -timescale 1ns/1ps \
    -L uvm \
    -debug typical 2>@1

# ── Step 3: Simulate ──
puts "\n>>> Step 3: Running simulation..."
exec xsim soc_sim_snapshot \
    -testplusarg "UVM_TESTNAME=$test_name" \
    -testplusarg "UVM_VERBOSITY=$verbosity" \
    -runall \
    -log sim_${test_name}.log 2>@1

puts "\n═══════════════════════════════════════════"
puts " Simulation complete. Log: sim_${test_name}.log"
puts "═══════════════════════════════════════════"
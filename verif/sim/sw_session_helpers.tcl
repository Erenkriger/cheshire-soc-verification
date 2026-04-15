# ============================================================================
# sw_session_helpers.tcl
#
# Helper commands to run SW tests from within Questa transcript.
#
# Usage (from verif/build after make compile TEST=chs_sw_external_test):
#   do ../sim/sw_session_helpers.tcl
#   sw_open_test test_lvl_easy_uart_hello
#   run -all
#
# Optional quick run:
#   sw_run_test test_lvl_easy_uart_hello
# ============================================================================

proc sw_open_test {test_name {verbosity UVM_MEDIUM}} {
    set sim_timeout 10000000000000
    set timeout_cycles 700000
    set words_file [format "../sw/build/%s.words" $test_name]

    if {![file exists $words_file]} {
        puts [format {ERROR: Words file not found: %s} $words_file]
        puts {Build firmware first: make -C ../sw all}
        return -code error
    }

    eval vsim -64 -t 1ps -suppress 12110 \
        -sv_seed random \
        +UVM_TESTNAME=chs_sw_external_test \
        [format +UVM_VERBOSITY=%s $verbosity] \
        [format +UVM_TIMEOUT=%s $sim_timeout] \
        [format +SW_WORDS_FILE=%s $words_file] \
        [format +SW_TEST_NAME=%s $test_name] \
        [format +SW_TIMEOUT_CYCLES=%s $timeout_cycles] \
        work.tb_top

    do ../sim/sw_wave_setup.tcl
    sw_wave_for_test $test_name
    log -r /*

    puts [format {Opened test=%s verbosity=%s with waveform groups. Next: run -all} $test_name $verbosity]
}

proc sw_run_test {test_name {verbosity UVM_MEDIUM}} {
    sw_open_test $test_name $verbosity
    run -all
}

proc sw_note_header {test_name} {
    puts {============================================================}
    puts [format {WAVE REVIEW CHECKLIST: %s} $test_name]
    puts {1) Reset release and boot_mode transition}
    puts {2) Program load phase (AXI writes to DRAM via JTAG/debug path)}
    puts {3) Firmware active phase (UART/GPIO/SPI/I2C depending on test)}
    puts {4) EOC write to SCRATCH[2] and clean finish}
    puts {============================================================}
}

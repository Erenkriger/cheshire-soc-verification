# ============================================================================
# run_all_tests.tcl — Run all UVM tests sequentially (batch-safe)
#
# Usage (GUI — from cheshire/target/sim/vsim/):
#   do $env(SOC_UVM)/verif/sim/run_all_tests.tcl
#
# Usage (Batch — no GUI needed, runs unattended):
#   cd $SOC_UVM/cheshire/target/sim/vsim
#   vsim -64 -c -do "do $env(SOC_UVM)/verif/sim/run_all_tests.tcl"
#
# Results are logged to: $SOC_UVM/verif/sim/regression_results.log
# Individual test logs:  $SOC_UVM/verif/sim/logs/<test_name>.log
# ============================================================================

# ─── Prevent "Finish Vsim" popup on $finish ───
# In GUI mode, $finish causes a break+dialog. This tells QuestaSim
# to resume automatically instead of popping up the dialog.
onbreak {resume}

set test_list {
    chs_sanity_test
    chs_jtag_boot_test
    chs_uart_test
    chs_jtag_idcode_test
    chs_jtag_dmi_test
    chs_uart_tx_test
    chs_uart_burst_test
    chs_spi_single_test
    chs_spi_flash_test
    chs_i2c_write_test
    chs_i2c_rd_test
    chs_gpio_walk_test
    chs_gpio_toggle_test
    chs_jtag_sba_test
    chs_spi_sba_test
    chs_i2c_sba_test
    chs_gpio_deep_test
    chs_cross_protocol_test
    chs_stress_test
    chs_sva_coverage_test
    chs_ral_access_test
    chs_interrupt_test
    chs_error_inject_test
    chs_concurrent_test
    chs_memmap_test
    chs_boot_seq_test
    chs_reg_reset_test
    chs_periph_stress_test
    chs_axi_sanity_test
    chs_axi_stress_test
    chs_axi_protocol_test
    chs_cov_jtag_corner_test
    chs_cov_uart_boundary_test
    chs_cov_gpio_exhaustive_test
    chs_cov_axi_region_test
    chs_cov_allproto_test
    chs_bootrom_fetch_test
    chs_slink_test
    chs_vga_test
    chs_usb_test
    chs_idma_test
    chs_dram_bist_test
}

set total   [llength $test_list]
set passed  0
set failed  0
set results {}

# ─── Create logs directory & UCDB directory & open summary log ───
file mkdir "$env(SOC_UVM)/verif/sim/logs"
file mkdir "$env(SOC_UVM)/verif/sim/ucdb"
set log_file "$env(SOC_UVM)/verif/sim/regression_results.log"
set log_fd [open $log_file w]
set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
puts $log_fd "========================================================================"
puts $log_fd "  UVM Regression Results — $timestamp"
puts $log_fd "  Total tests: $total"
puts $log_fd "========================================================================"
puts $log_fd ""

puts "========================================================================"
puts "  UVM Regression — $total tests"
puts "========================================================================"

set test_idx 0
foreach test $test_list {
    incr test_idx

    puts "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "  \[$test_idx/$total\] START: $test"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Each test gets its own transcript log
    set test_log "$env(SOC_UVM)/verif/sim/logs/${test}.log"
    set test_ucdb "$env(SOC_UVM)/verif/sim/ucdb/${test}.ucdb"

    # Launch simulation with -onfinish stop to prevent auto-quit
    # -coverage enables code + functional coverage collection
    vsim -64 -voptargs="+acc" work.tb_top -t 1ps \
        -suppress 12110 \
        -onfinish stop \
        -coverage \
        +UVM_TESTNAME=$test \
        +UVM_VERBOSITY=UVM_MEDIUM \
        -l $test_log

    # Run until $finish (which will 'stop' due to -onfinish stop)
    run -all

    # ─── Save coverage database for this test ───
    coverage save $test_ucdb

    # ─── Parse test log for PASS/FAIL status ───
    set status "PASSED"
    if {[file exists $test_log]} {
        set fd [open $test_log r]
        set content [read $fd]
        close $fd

        # Check for UVM_FATAL
        if {[regexp {UVM_FATAL\s*:\s*([0-9]+)} $content -> fatal_count]} {
            if {$fatal_count > 0} {
                set status "FAILED (UVM_FATAL: $fatal_count)"
            }
        }
        # Check for UVM_ERROR
        if {[regexp {UVM_ERROR\s*:\s*([0-9]+)} $content -> error_count]} {
            if {$error_count > 0 && $status eq "PASSED"} {
                set status "FAILED (UVM_ERROR: $error_count)"
            }
        }
    }

    # End this simulation instance
    quit -sim

    # Record result
    if {[string match "PASSED*" $status]} {
        incr passed
    } else {
        incr failed
    }
    lappend results [list $test $status]

    puts "  RESULT: $test => $status"
    puts $log_fd [format "  \[%2d\] %-35s %s" $test_idx $test $status]
}

# ─── Final Summary ───
puts "\n"
puts "========================================================================"
puts "  REGRESSION SUMMARY"
puts "========================================================================"
puts [format "  %-35s %s" "Test Name" "Result"]
puts "  ---------------------------------------------------"

puts $log_fd ""
puts $log_fd "========================================================================"
puts $log_fd "  REGRESSION SUMMARY"
puts $log_fd "========================================================================"
puts $log_fd [format "  %-35s %s" "Test Name" "Result"]
puts $log_fd "  ---------------------------------------------------"

foreach r $results {
    set tname  [lindex $r 0]
    set tres   [lindex $r 1]
    set line [format "  %-35s %s" $tname $tres]
    puts $line
    puts $log_fd $line
}

puts "========================================================================"
puts "  Total: $total  |  Passed: $passed  |  Failed: $failed"
puts "========================================================================"

puts $log_fd "========================================================================"
puts $log_fd "  Total: $total  |  Passed: $passed  |  Failed: $failed"
puts $log_fd "========================================================================"

close $log_fd

# ─── Merge all individual logs into one combined file ───
set combined_file "$env(SOC_UVM)/verif/sim/logs/ALL_TESTS_COMBINED.log"
set cfd [open $combined_file w]
puts $cfd "╔══════════════════════════════════════════════════════════════════════╗"
puts $cfd "║  COMBINED UVM REGRESSION LOG — $timestamp"
puts $cfd "║  Total tests: $total  |  Passed: $passed  |  Failed: $failed"
puts $cfd "╚══════════════════════════════════════════════════════════════════════╝"
puts $cfd ""

foreach test $test_list {
    set test_log "$env(SOC_UVM)/verif/sim/logs/${test}.log"
    puts $cfd "┌──────────────────────────────────────────────────────────────────────"
    puts $cfd "│  TEST: $test"
    puts $cfd "└──────────────────────────────────────────────────────────────────────"
    if {[file exists $test_log]} {
        set fd [open $test_log r]
        # Read only UVM-relevant lines (skip QuestaSim noise)
        while {[gets $fd line] >= 0} {
            if {[regexp {UVM_|SCB_|SBA|DMI|JTAG|GPIO|UART|SPI|I2C|IDCODE|AXI|ATOP|PROTOCOL|Scoreboard|PASSED|FAILED|Report|SLINK|VGA|USB|IDMA|DRAM|BIST|BOOTROM} $line]} {
                puts $cfd "  $line"
            }
        }
        close $fd
    } else {
        puts $cfd "  [WARNING] Log file not found: $test_log"
    }
    puts $cfd ""
}

# Append summary table at end
puts $cfd "╔══════════════════════════════════════════════════════════════════════╗"
puts $cfd "║  REGRESSION SUMMARY"
puts $cfd "╠══════════════════════════════════════════════════════════════════════╣"
foreach r $results {
    set tname  [lindex $r 0]
    set tres   [lindex $r 1]
    puts $cfd [format "║  %-35s %s" $tname $tres]
}
puts $cfd "╠══════════════════════════════════════════════════════════════════════╣"
puts $cfd [format "║  Total: %d  |  Passed: %d  |  Failed: %d" $total $passed $failed]
puts $cfd "╚══════════════════════════════════════════════════════════════════════╝"
close $cfd

puts ""
puts "  Results saved to: $log_file"
puts "  Combined log:     $combined_file"
puts "  Individual test logs: $env(SOC_UVM)/verif/sim/logs/"

# ═══════════════════════════════════════════════════════════════════
# ─── UCDB Coverage Merge & Report ───
# ═══════════════════════════════════════════════════════════════════
puts ""
puts "========================================================================"
puts "  COVERAGE MERGE & REPORT"
puts "========================================================================"

set ucdb_dir "$env(SOC_UVM)/verif/sim/ucdb"
set merged_ucdb "$ucdb_dir/merged_all_tests.ucdb"
set report_dir "$env(SOC_UVM)/verif/sim/coverage_report"
set report_txt "$env(SOC_UVM)/verif/sim/coverage_summary.txt"

# Collect all UCDB files
set ucdb_files [glob -nocomplain $ucdb_dir/*.ucdb]
set ucdb_count [llength $ucdb_files]

if {$ucdb_count > 0} {
    puts "  Found $ucdb_count UCDB files to merge..."

    # Build vcover merge command
    set merge_cmd "vcover merge -out $merged_ucdb"
    foreach uf $ucdb_files {
        # Skip the merged file itself if it exists from a prior run
        if {[string match "*merged_all_tests*" $uf]} continue
        append merge_cmd " $uf"
    }

    puts "  Running: vcover merge ..."
    if {[catch {eval exec $merge_cmd} merge_result]} {
        puts "  \[WARNING\] vcover merge returned: $merge_result"
    } else {
        puts "  vcover merge completed successfully!"
    }

    # Generate text report
    if {[file exists $merged_ucdb]} {
        puts "  Generating text coverage report..."
        if {[catch {exec vcover report -details $merged_ucdb} report_out]} {
            puts "  \[WARNING\] vcover report returned: $report_out"
            # Even warnings often contain the report, save it
            set rfd [open $report_txt w]
            puts $rfd $report_out
            close $rfd
        } else {
            set rfd [open $report_txt w]
            puts $rfd $report_out
            close $rfd
            puts "  Text report saved: $report_txt"
        }

        # Generate HTML report
        puts "  Generating HTML coverage report..."
        file mkdir $report_dir
        if {[catch {exec vcover report -html $merged_ucdb -htmldir $report_dir} html_result]} {
            puts "  \[WARNING\] vcover HTML report: $html_result"
        } else {
            puts "  HTML report saved: $report_dir/index.html"
        }
    } else {
        puts "  \[ERROR\] Merged UCDB not found after merge!"
    }
} else {
    puts "  \[WARNING\] No UCDB files found in $ucdb_dir"
}

puts ""
puts "========================================================================"
puts "  REGRESSION + COVERAGE COMPLETE"
puts "========================================================================"
puts "  Test Results: $log_file"
puts "  Coverage DB:  $merged_ucdb"
puts "  Coverage Report (text): $report_txt"
puts "  Coverage Report (HTML): $report_dir/index.html"
puts "========================================================================"

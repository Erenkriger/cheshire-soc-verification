# Demo Runbook — Canlı Sunum Komut Planı

## 1) Derleme

```bash
export SOC_UVM=/home/eren.kacmaz/SOC_UVM
cd $SOC_UVM/cheshire/target/sim/vsim
vlog -64 -f $SOC_UVM/verif/sim/compile_uvm_tb.f
```

Beklenen: Errors 0, Warnings 0.

## 2) SW Hello Test

```bash
vsim -64 -c -do "run -all; quit -f" \
  +UVM_TESTNAME=chs_sw_hello_test \
  +UVM_VERBOSITY=UVM_MEDIUM \
  -suppress 3009 -suppress 8386 \
  -sv_seed random tb_top
```

Log imzaları:
- `Core halted successfully`
- `ABSTRACTCS ... cmderr=0`
- `DMSTATUS after resume ... allrunning=1`
- `EOC detected`
- `SW TEST PASSED`

## 3) SW GPIO Test

```bash
vsim -64 -c -do "run -all; quit -f" \
  +UVM_TESTNAME=chs_sw_gpio_test \
  +UVM_VERBOSITY=UVM_MEDIUM \
  -suppress 3009 -suppress 8386 \
  -sv_seed random tb_top
```

Log imzaları:
- `Built GPIO test program`
- `Writing ... words to DRAM`
- `Core is running from DRAM entry point`
- `SW TEST PASSED`

## 4) Full Regression (44 test)

```bash
vsim -64 -c -do "source $env(SOC_UVM)/verif/sim/run_all_tests.tcl"
```

Rapor dosyası:
- `$SOC_UVM/verif/sim/regression_results.log`

## 5) Coverage Merge + Report

```bash
vcover merge -64 \
  $SOC_UVM/verif/sim/ucdb/merged_coverage.ucdb \
  $SOC_UVM/verif/sim/ucdb/chs_*.ucdb

vcover report -64 \
  $SOC_UVM/verif/sim/ucdb/merged_coverage.ucdb \
  -details \
  -output $SOC_UVM/verif/sim/coverage_summary.txt
```

Kontrol satırları:
- `Total Coverage By Instance`
- `Covergroups`
- `Covergroup Bins`
- `cp_dmi_op`
- `cp_dmi_addr`

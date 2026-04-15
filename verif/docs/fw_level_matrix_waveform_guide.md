# Firmware Level Matrix and Waveform Guide

This guide defines the 3 easy + 5 medium + 5 hard firmware tests and what to expect in waveform/log review.

## 1) Level Matrix

### Easy (3)
- `test_lvl_easy_uart_hello`
- `test_lvl_easy_gpio_basic`
- `test_lvl_easy_mem_smoke`

### Medium (5)
- `test_lvl_medium_memmap_probe`
- `test_lvl_medium_uart_pattern`
- `test_lvl_medium_gpio_irq_cfg`
- `test_lvl_medium_spi_i2c_cfg`
- `test_lvl_medium_interleave_rw`

### Hard (5)
- `test_lvl_hard_idma_multi_copy`
- `test_lvl_hard_spm_dram_march_mix`
- `test_lvl_hard_longrun_protocol_mix`
- `test_lvl_hard_periph_stress_matrix`
- `test_lvl_hard_recovery_resilience`

## 2) Common Pass/Fail Markers

For every run of `chs_sw_external_test`:

1. JTAG load phase writes program words to DRAM base `0x8000_0000`.
2. Core resumes and executes firmware image.
3. Firmware terminates via `_exit` path and writes EOC register `SCRATCH[2]` (`0x0300_0008`).
4. Pass condition: EOC raw value has bit0=`1` and exit code=`0`.
5. Fail condition: exit code non-zero or timeout in EOC polling.

## 3) Waveform Checkpoints per Test Group

### Easy Group
- UART activity is visible early (`UART_BASE + THR` writes).
- GPIO easy test shows `GPIO_DIRECT_OE` then `GPIO_DIRECT_OUT` pattern writes.
- Memory smoke shows small SPM (`0x1000_xxxx`) and DRAM (`0x800x_xxxx`) write/read bursts.

### Medium Group
- Memmap probe accesses multiple base regions (UART/SPI/I2C/GPIO/CLINT/PLIC/BOOTROM).
- UART pattern test produces sustained UART TX with periodic CR/LF.
- GPIO IRQ config test writes interrupt-enable/test/state registers.
- SPI/I2C config test shows both protocol control paths active in one run.
- Interleave test alternates MMIO + DRAM ring writes in a tight loop.

### Hard Group
- iDMA multi-copy test shows iDMA config writes, transfer launch, done-id polling, and destination memory updates.
- March mix test shows ordered up/down memory sweeps over SPM and DRAM windows.
- Long-run protocol mix exhibits long mixed traffic with periodic UART dots.
- Peripheral stress matrix toggles SPI/I2C/GPIO/UART-related registers in dense loops.
- Recovery resilience test repeatedly reconfigures UART/SPI/I2C and ends with stable health-check state.

## 4) Report Template (Expected vs Observed)

Use this structure in your supervisor report:

1. Test Name
2. Level (Easy/Medium/Hard)
3. Expected waveform markers
4. Observed waveform markers
5. Expected log markers (`SW TEST PASSED` and `exit_code=0`)
6. Observed log markers
7. Result (PASS/FAIL)
8. Notes / anomaly / next action

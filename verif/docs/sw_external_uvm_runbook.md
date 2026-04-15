# SW External UVM Runbook

## 1) Build all C tests

```bash
cd /home/tutel/SOC_UVM/verif/sw
make all
```

This generates:

- `build/*.elf`
- `build/*.dump`
- `build/*.memh`
- `build/*.words` (one 32-bit hex word per line, for UVM SW loader)

## 2) Run one C test in UVM (batch)

```bash
cd /home/tutel/SOC_UVM/verif
make sim TEST=chs_sw_external_test \
  SIM_TIME=10000000000000 \
  VERBOSITY=UVM_MEDIUM \
  PLUSARGS='+SW_WORDS_FILE=../sw/build/test_gpio_deep.words +SW_TEST_NAME=test_gpio_deep +SW_TIMEOUT_CYCLES=400000'
```

## 3) Run one C test in UVM (GUI + waveform)

```bash
cd /home/tutel/SOC_UVM/verif
make sim_gui TEST=chs_sw_external_test \
  SIM_TIME=10000000000000 \
  VERBOSITY=UVM_MEDIUM \
  PLUSARGS='+SW_WORDS_FILE=../sw/build/test_gpio_deep.words +SW_TEST_NAME=test_gpio_deep +SW_TIMEOUT_CYCLES=400000'
```

## 4) Run all generated C tests through UVM

```bash
cd /home/tutel/SOC_UVM/verif
bash sim/run_sw_external_regression.sh
```

## 5) Waveform + UVM result checks

- Use `sim_gui` for interactive waveform and monitor transactions.
- UVM pass/fail is decided by SCRATCH[2] EOC decode in `chs_sw_driven_vseq`.
- Batch logs are under `verif/sim/logs/`.
- If coverage is enabled in your flow, collect UCDB and merge with `vcover`.

## 6) Useful plusargs

- `+SW_WORDS_FILE=../sw/build/<test>.words` : select C test image
- `+SW_TEST_NAME=<name>` : UVM log label
- `+SW_TIMEOUT_CYCLES=<n>` : polling timeout for EOC

## 7) Timeout note

- In this setup, use numeric `SIM_TIME` (in simulator time units) rather than `ms/us` suffixes.
- Recommended baseline: `SIM_TIME=10000000000000`

# FW Observation Report — `test_lvl_extreme_sys_bench`

Date: 2026-04-15
Run Mode: SW-driven external FW test via `chs_sw_external_test`
Log File: `verif/sim/logs/test_lvl_extreme_sys_bench.gui.log`
Story File: `verif/sim/logs/test_lvl_extreme_sys_bench.gui.story.txt`

---

## 1) Test Intent

This test was created as an open-source inspired stress workload combining:

1. Matrix multiplication (compute and memory traffic)
2. Recursive Towers of Hanoi (branch/stack pressure)
3. CRC32 over a memory buffer (data-path and memory pressure)

Expected behavior:

- CPU should execute all 3 phases.
- UART should print progress banners and cycle counts.
- FW should return from `main` (or explicitly signal EOC), causing EOC at `SCRATCH[2]`.

---

## 2) Final Verdict of This Run

Result: **FAIL (TIMEOUT)**

Evidence:

- UVM fatal timeout occurred at 100 ms simulation time.
- No SW pass/fail line was emitted.
- No EOC detect line was emitted.

Key lines:

- `UVM_FATAL ... Test timeout after 100000000000`
- `UVM_FATAL : 1`
- `EOC polling continued: 1000/2000/3000/4000/5000 polls`

---

## 3) Execution Timeline (From Log)

1. `[1/7]` JTAG TAP reset + SBA init
2. `[2/7]` IDCODE verified (`0x1c5e5db3`)
3. `[3/7]` Core halted via debug
4. `[4/7]` EOC register cleared (`SCRATCH[2]`)
5. `[5/7]` External words loaded to DRAM:
   - Loaded words: `810`
   - Address range: `[0x80000000 - 0x80000ca7]`
   - Verify first words: OK
6. `[6/7]` PC set to DRAM entry and core resumed
   - `allrunning=1 allhalted=0 resumeack=1`
7. `[7/7]` Poll `SCRATCH[2]` for EOC
   - EOC never changed from `0`
   - Test timed out at 100 ms

---

## 4) Interface/Protocol Utilization Summary

From `test_lvl_extreme_sys_bench.gui.log`:

- `AR handshake`: **164**
- `R COMPLETE`: **164**
- `AW handshake`: **0**
- `B COMPLETE`: **0**
- `SCB_AXI AXI READ`: **164**
- `SCB_AXI AXI WRITE`: **0**
- `SCB_UART`: **0**
- `SCB_GPIO`: **0**
- `SCB_SPI`: **0**
- `SCB_I2C`: **0**

Address profile of monitored AXI traffic:

- Min AR address: `0x0000000080000000`
- Max AR address: `0x000000008000ffc0`
- Unique AR addresses: `164`

Peripheral monitor start-only messages seen, but no transaction evidence:

- `UART_MON` start message only
- `SPI_MON` start message only

JTAG/debug-side activity was heavy:

- `SCB_JTAG`: `26623`
- `SBA write OK`: `811`
- `SBA read OK`: `5840`

Interpretation:

- The system clearly performed debug-driven memory load + EOC polling.
- CPU-visible monitored AXI channel showed read-only fetch behavior.
- Intended peripheral and data-write stress did **not** materialize in this run.

---

## 5) Waveform Correlation

Waveform snapshots are consistent with the log:

1. AXI read channel (`AR/R`) shows bursts.
2. AXI write channels (`AW/W/B`) remain idle.
3. UART/GPIO/SPI/I2C wave groups remain mostly static.
4. Long post-load interval with no completion event, matching EOC polling timeout.

---

## 6) Code-Level Analysis of Likely Stall Point

In `test_lvl_extreme_sys_bench.c`, `main()` starts with:

- `print_str("[SYS_BENCH] ...")`

`print_str()` is a blocking loop waiting for UART THRE:

```c
while ((REG32(UART_BASE, 0x14) & 0x20) == 0);
```

No timeout guard exists in this loop.

Because the run shows:

- no `SCB_UART` traffic,
- no `SYS_BENCH` string evidence in the transcript,
- and no EOC completion,

the strongest hypothesis is that FW got stuck before completing benchmark phases, very likely in a blocking UART readiness wait path.

---

## 7) Why This Matters for SoC Stress-Test Quality

A strong SoC C stress test must be:

1. **Progress-observable**: phase checkpoints must be written to a debug-visible register.
2. **Non-blocking on peripheral bring-up**: UART/SPI waits need bounded timeouts.
3. **Fail-fast**: if a dependency is missing (e.g., UART not ready), return an explicit non-zero code.
4. **Self-diagnosing**: encode fail stage (e.g., `phase_id`) into EOC value.

Without these, timeout gives low diagnostic value even when infrastructure is healthy.

---

## 8) Recommended Fixes Before Next Run

1. Replace custom blocking print with robust helper (`uart_putc`) plus timeout wrapper.
2. Add phase markers to `CHS_SCRATCH0/1` at each benchmark stage.
3. Keep explicit `signal_eoc(ret)` at end (or return code) and stage-coded error exits.
4. Add compile-time knobs for stress scaling:
   - `MATRIX_SIZE`
   - `HANOI_DISKS`
   - `MEM_BLOCK_SIZE`
   - outer iteration count (to target 30-60 min sim)
5. Re-run and compare:
   - `SCB_AXI` read/write counts
   - peripheral scoreboard activity
   - EOC latency

---

## 9) Management-Facing One-Liners

1. "Bu koşuda altyapı doğru çalıştı; debug üzerinden FW başarıyla DRAM'e yüklendi ve CPU resume edildi, ancak firmware EOC üretmediği için test 100 ms timeout ile sonlandı."
2. "AXI monitörde 164 read ve 0 write görüyoruz; yani hedeflenen memory-write ve peripheral-stress fazları aktive olmamış."
3. "Bu sonuç bize test kodunun doğrulama olgunluğunu artırmamız gerektiğini gösteriyor: peripheral wait noktaları timeout'lu olmalı ve her faz scratch register checkpoint'i üretmeli."
4. "Bir sonraki iterasyonda aynı testi fail-fast ve stage-coded EOC ile tekrar koşup gerçek SoC stres kapsamını sayısal olarak çıkaracağız."

# =============================================================================
# crt0.S — Minimal C Runtime Startup for Cheshire SoC bare-metal tests
# Compatible with RV64GC, targets SPM at 0x10000000
# =============================================================================

.section .text.start, "ax", @progbits
.globl _start
.type  _start, @function

_start:
    # ─── Disable interrupts ───
    csrrc   x0, mstatus, 0x8       # Clear MIE bit

    # ─── Set stack pointer (end of SPM: 0x1000_FFFC) ───
    la      sp, __stack_pointer
    la      gp, __global_pointer

    # ─── Zero BSS section ───
    la      t0, __bss_start
    la      t1, __bss_end
1:
    bge     t0, t1, 2f
    sd      x0, 0(t0)
    addi    t0, t0, 8
    j       1b
2:

    # ─── Call main() ───
    fence
    call    main

    # ─── Fall through to _exit ───
    # a0 contains return value from main()

.globl _exit
.type  _exit, @function
_exit:
    # Encode return value: (retval << 1) | 1
    slli    t0, a0, 1
    ori     t0, t0, 1

    # Write to CHESHIRE SCRATCH[2] at 0x0300_0008
    li      t1, 0x03000000
    sw      t0, 8(t1)

    # Infinite loop (halt)
3:
    wfi
    j       3b

.size _start, . - _start

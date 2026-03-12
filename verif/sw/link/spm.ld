/* ═══════════════════════════════════════════════════════════════
 * spm.ld — Linker script for Cheshire SoC bare-metal tests
 * Targets SPM (Scratchpad Memory) at 0x1000_0000, 64 KiB
 * ═══════════════════════════════════════════════════════════════ */

OUTPUT_ARCH("riscv")
ENTRY(_start)

/* ─── Peripheral base addresses (linker symbols) ─── */
__base_regs  = 0x03000000;
__base_llc   = 0x03001000;
__base_uart  = 0x03002000;
__base_i2c   = 0x03003000;
__base_spih  = 0x03004000;
__base_gpio  = 0x03005000;
__base_slink = 0x03006000;
__base_vga   = 0x03007000;
__base_usb   = 0x03008000;
__base_clint = 0x02040000;
__base_plic  = 0x04000000;
__base_spm   = 0x10000000;
__base_dram  = 0x80000000;

MEMORY
{
    spm  (rwx) : ORIGIN = 0x10000000, LENGTH = 64K
}

SECTIONS
{
    . = ORIGIN(spm);

    .text : {
        *(.text.start)      /* _start must be first */
        *(.text .text.*)
    } > spm

    .rodata : ALIGN(8) {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > spm

    .data : ALIGN(8) {
        __global_pointer = . + 0x800;
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > spm

    .bss (NOLOAD) : ALIGN(8) {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        __bss_end = .;
    } > spm

    /* Stack at end of SPM */
    . = ALIGN(16);
    __stack_start = .;
    . = ORIGIN(spm) + LENGTH(spm) - 16;
    __stack_pointer = .;
}

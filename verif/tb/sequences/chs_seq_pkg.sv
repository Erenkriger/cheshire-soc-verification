// ============================================================================
// chs_seq_pkg.sv — Cheshire SoC Sequence Package
// Imports agent packages and environment package, includes all
// IP-level and virtual sequences.
// ============================================================================

package chs_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import agent packages (transaction & sequencer types)
    import jtag_pkg::*;
    import uart_pkg::*;
    import spi_pkg::*;
    import i2c_pkg::*;
    import gpio_pkg::*;
    import slink_pkg::*;
    import usb_pkg::*;

    // Import environment package (virtual sequencer type)
    import chs_env_pkg::*;

    // Import RAL package (register model types)
    import chs_ral_pkg::*;

    // ----- IP-level sequences -----
    `include "ip/jtag_base_seq.sv"
    `include "ip/uart_base_seq.sv"
    `include "ip/spi_base_seq.sv"
    `include "ip/i2c_base_seq.sv"
    `include "ip/gpio_base_seq.sv"
    `include "ip/slink_base_seq.sv"
    `include "ip/usb_base_seq.sv"

    // ----- RAL frontdoor (depends on jtag_base_seq) -----
    `include "virtual/chs_ral_frontdoor_seq.sv"

    // ----- Virtual sequences -----
    `include "virtual/chs_smoke_vseq.sv"
    `include "virtual/chs_boot_jtag_vseq.sv"
    `include "virtual/chs_jtag_idcode_vseq.sv"
    `include "virtual/chs_jtag_dmi_vseq.sv"
    `include "virtual/chs_uart_tx_vseq.sv"
    `include "virtual/chs_uart_burst_vseq.sv"
    `include "virtual/chs_spi_single_vseq.sv"
    `include "virtual/chs_spi_flash_vseq.sv"
    `include "virtual/chs_i2c_write_vseq.sv"
    `include "virtual/chs_i2c_rd_vseq.sv"
    `include "virtual/chs_gpio_walk_vseq.sv"
    `include "virtual/chs_gpio_toggle_vseq.sv"
    `include "virtual/chs_jtag_sba_vseq.sv"
    `include "virtual/chs_spi_sba_vseq.sv"
    `include "virtual/chs_i2c_sba_vseq.sv"
    `include "virtual/chs_gpio_deep_vseq.sv"
    `include "virtual/chs_cross_protocol_vseq.sv"
    `include "virtual/chs_stress_vseq.sv"
    `include "virtual/chs_coverage_drive_vseq.sv"

    // ----- Aşama 6: RAL + Advanced Scenarios -----
    `include "virtual/chs_ral_access_vseq.sv"
    `include "virtual/chs_interrupt_vseq.sv"
    `include "virtual/chs_error_inject_vseq.sv"
    `include "virtual/chs_concurrent_vseq.sv"

    // ----- Aşama 7: SoC-Level Integration Tests -----
    `include "virtual/chs_memmap_vseq.sv"
    `include "virtual/chs_boot_seq_vseq.sv"
    `include "virtual/chs_reg_reset_vseq.sv"
    `include "virtual/chs_periph_stress_vseq.sv"

    // ----- Aşama 9: Coverage Boost Sequences -----
    `include "virtual/chs_cov_jtag_corner_vseq.sv"
    `include "virtual/chs_cov_uart_boundary_vseq.sv"
    `include "virtual/chs_cov_gpio_exhaustive_vseq.sv"
    `include "virtual/chs_cov_axi_region_vseq.sv"
    `include "virtual/chs_cov_allproto_vseq.sv"

    // ----- Aşama 10: Out-of-Scope IP Verification -----
    `include "virtual/chs_bootrom_fetch_vseq.sv"
    `include "virtual/chs_slink_vseq.sv"
    `include "virtual/chs_vga_vseq.sv"
    `include "virtual/chs_usb_vseq.sv"
    `include "virtual/chs_idma_vseq.sv"
    `include "virtual/chs_dram_bist_vseq.sv"

endpackage : chs_seq_pkg

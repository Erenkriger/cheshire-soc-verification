// ============================================================================
// chs_test_pkg.sv — Cheshire SoC Test Package
// Imports environment and sequence packages, includes all test files.
// ============================================================================

package chs_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import agent packages (needed for config types)
    import jtag_pkg::*;
    import uart_pkg::*;
    import spi_pkg::*;
    import i2c_pkg::*;
    import gpio_pkg::*;
    import chs_axi_pkg::*;
    import slink_pkg::*;
    import vga_pkg::*;
    import usb_pkg::*;

    // Import environment & sequence packages
    import chs_env_pkg::*;
    import chs_seq_pkg::*;

    // Import RAL package
    import chs_ral_pkg::*;

    // ----- Test files (order: base first, then derived) -----
    `include "chs_base_test.sv"
    `include "chs_sanity_test.sv"
    `include "chs_jtag_boot_test.sv"
    `include "chs_uart_test.sv"
    `include "chs_jtag_idcode_test.sv"
    `include "chs_jtag_dmi_test.sv"
    `include "chs_uart_tx_test.sv"
    `include "chs_uart_burst_test.sv"
    `include "chs_spi_single_test.sv"
    `include "chs_spi_flash_test.sv"
    `include "chs_i2c_write_test.sv"
    `include "chs_i2c_rd_test.sv"
    `include "chs_gpio_walk_test.sv"
    `include "chs_gpio_toggle_test.sv"
    `include "chs_jtag_sba_test.sv"
    `include "chs_spi_sba_test.sv"
    `include "chs_i2c_sba_test.sv"
    `include "chs_gpio_deep_test.sv"
    `include "chs_cross_protocol_test.sv"
    `include "chs_stress_test.sv"
    `include "chs_sva_coverage_test.sv"

    // ----- Aşama 6: RAL + Advanced Scenarios -----
    `include "chs_ral_access_test.sv"
    `include "chs_interrupt_test.sv"
    `include "chs_error_inject_test.sv"
    `include "chs_concurrent_test.sv"

    // ----- Aşama 7: SoC-Level Integration Tests -----
    `include "chs_memmap_test.sv"
    `include "chs_boot_seq_test.sv"
    `include "chs_reg_reset_test.sv"
    `include "chs_periph_stress_test.sv"

    // ----- Aşama 8: AXI Bus Verification Tests -----
    `include "chs_axi_sanity_test.sv"
    `include "chs_axi_stress_test.sv"
    `include "chs_axi_protocol_test.sv"

    // ----- Aşama 9: Coverage Boost Tests -----
    `include "chs_cov_jtag_corner_test.sv"
    `include "chs_cov_uart_boundary_test.sv"
    `include "chs_cov_gpio_exhaustive_test.sv"
    `include "chs_cov_axi_region_test.sv"
    `include "chs_cov_allproto_test.sv"

    // ----- Aşama 10: Out-of-Scope IP Verification Tests -----
    `include "chs_bootrom_fetch_test.sv"
    `include "chs_slink_test.sv"
    `include "chs_vga_test.sv"
    `include "chs_usb_test.sv"
    `include "chs_idma_test.sv"
    `include "chs_dram_bist_test.sv"

    // ----- Aşama 11: SW-Driven Verification Tests -----
    `include "chs_sw_hello_test.sv"
    `include "chs_sw_gpio_test.sv"

endpackage : chs_test_pkg

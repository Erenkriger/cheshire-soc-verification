`ifndef CHS_SPI_FLASH_TEST_SV
`define CHS_SPI_FLASH_TEST_SV

// ============================================================================
// chs_spi_flash_test.sv — SPI Flash Read Test
// Simulates JEDEC ID read + Flash data read command sequence.
// ============================================================================

class chs_spi_flash_test extends chs_base_test;

    `uvm_component_utils(chs_spi_flash_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_spi_flash_vseq vseq;

        `uvm_info(get_type_name(), "===== SPI Flash Test START =====", UVM_LOW)

        vseq = chs_spi_flash_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== SPI Flash Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_spi_flash_test

`endif

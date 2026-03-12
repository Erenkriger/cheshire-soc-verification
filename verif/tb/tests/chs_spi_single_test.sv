`ifndef CHS_SPI_SINGLE_TEST_SV
`define CHS_SPI_SINGLE_TEST_SV

// ============================================================================
// chs_spi_single_test.sv — SPI Single Transfer Test
// Sends individual SPI bytes and reads dummy data.
// ============================================================================

class chs_spi_single_test extends chs_base_test;

    `uvm_component_utils(chs_spi_single_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_spi_single_vseq vseq;

        `uvm_info(get_type_name(), "===== SPI Single Test START =====", UVM_LOW)

        vseq = chs_spi_single_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== SPI Single Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_spi_single_test

`endif

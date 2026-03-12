`ifndef CHS_SPI_SBA_TEST_SV
`define CHS_SPI_SBA_TEST_SV

// ============================================================================
// chs_spi_sba_test.sv — SPI Host SBA System Bus Access Test
//
// Exercises the full SoC-level path for SPI Host:
//   JTAG → DMI → Debug Module → SBA → AXI → Regbus → SPI Host CSR → SPI Pins
//
// Timeout: 50ms — SBA operations through JTAG are inherently slow
// ============================================================================

class chs_spi_sba_test extends chs_base_test;

    `uvm_component_utils(chs_spi_sba_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;  // Increased: STATUS polling loop adds significant time
    endfunction

    virtual task test_body();
        chs_spi_sba_vseq vseq;

        `uvm_info(get_type_name(),
                  "========== SPI Host SBA Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
                  "Testing: JTAG -> SBA -> SPI Host CSR -> SPI Pins", UVM_LOW)

        vseq = chs_spi_sba_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
                  "========== SPI Host SBA Test Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_spi_sba_test

`endif // CHS_SPI_SBA_TEST_SV

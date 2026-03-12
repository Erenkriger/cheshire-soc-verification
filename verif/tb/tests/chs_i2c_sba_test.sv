`ifndef CHS_I2C_SBA_TEST_SV
`define CHS_I2C_SBA_TEST_SV

// ============================================================================
// chs_i2c_sba_test.sv — I2C SBA System Bus Access Test
//
// Exercises the full SoC-level path for I2C:
//   JTAG → DMI → Debug Module → SBA → AXI → Regbus → I2C CSR → I2C Pins
//
// Note: No I2C slave device on the bus — the master will generate
// START + address + data on SCL/SDA, but NACK is expected.
// The test uses NAKOK flag to tolerate NACK without error.
//
// Timeout: 100ms — I2C is slow (~100kHz) and SBA adds overhead
// ============================================================================

class chs_i2c_sba_test extends chs_base_test;

    `uvm_component_utils(chs_i2c_sba_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;
    endfunction

    virtual task test_body();
        chs_i2c_sba_vseq vseq;

        `uvm_info(get_type_name(),
                  "========== I2C SBA Test ==========", UVM_LOW)
        `uvm_info(get_type_name(),
                  "Testing: JTAG -> SBA -> I2C CSR -> SCL/SDA Pins", UVM_LOW)

        vseq = chs_i2c_sba_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
                  "========== I2C SBA Test Complete ==========", UVM_LOW)
    endtask : test_body

endclass : chs_i2c_sba_test

`endif // CHS_I2C_SBA_TEST_SV

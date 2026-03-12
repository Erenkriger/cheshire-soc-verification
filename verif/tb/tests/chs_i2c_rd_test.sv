`ifndef CHS_I2C_RD_TEST_SV
`define CHS_I2C_RD_TEST_SV

// ============================================================================
// chs_i2c_rd_test.sv — I2C Read-Back Test
// Writes 3 bytes to 0x50 then reads back 3 bytes.
// ============================================================================

class chs_i2c_rd_test extends chs_base_test;

    `uvm_component_utils(chs_i2c_rd_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_i2c_rd_vseq vseq;

        `uvm_info(get_type_name(), "===== I2C Read-Back Test START =====", UVM_LOW)

        vseq = chs_i2c_rd_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== I2C Read-Back Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_i2c_rd_test

`endif

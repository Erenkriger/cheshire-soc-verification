`ifndef CHS_I2C_WRITE_TEST_SV
`define CHS_I2C_WRITE_TEST_SV

// ============================================================================
// chs_i2c_write_test.sv — I2C Write Test
// Writes single bytes and a block to I2C slave address 0x50.
// ============================================================================

class chs_i2c_write_test extends chs_base_test;

    `uvm_component_utils(chs_i2c_write_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        chs_i2c_write_vseq vseq;

        `uvm_info(get_type_name(), "===== I2C Write Test START =====", UVM_LOW)

        vseq = chs_i2c_write_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== I2C Write Test PASSED =====", UVM_LOW)
    endtask : test_body

endclass : chs_i2c_write_test

`endif

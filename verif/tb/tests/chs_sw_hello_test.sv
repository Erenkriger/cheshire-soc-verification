`ifndef CHS_SW_HELLO_TEST_SV
`define CHS_SW_HELLO_TEST_SV

// ============================================================================
// chs_sw_hello_test.sv — SW-Driven Hello World Test
//
// Runs the built-in minimal firmware on the CVA6 processor via JTAG.
// The built-in test writes EOC=1 (PASS) to SCRATCH[2] without requiring
// any external binary compilation — ideal as a smoke test for the
// SW-driven verification flow itself.
// ============================================================================

class chs_sw_hello_test extends chs_base_test;

    `uvm_component_utils(chs_sw_hello_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 50ms;  // SW-driven tests need more time
    endfunction

    virtual task test_body();
        chs_sw_driven_vseq vseq;

        `uvm_info(get_type_name(),
            "===== SW-Driven Hello Test: Built-in Minimal Firmware =====", UVM_LOW)

        vseq = chs_sw_driven_vseq::type_id::create("vseq");
        vseq.test_name       = "builtin_hello";
        vseq.timeout_cycles  = 100000;
        // program_image left empty → load_builtin_test() will provide a
        // minimal program that writes EOC success to SCRATCH[2]

        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "===== SW-Driven Hello Test COMPLETE =====", UVM_LOW)
    endtask : test_body

endclass : chs_sw_hello_test

`endif // CHS_SW_HELLO_TEST_SV

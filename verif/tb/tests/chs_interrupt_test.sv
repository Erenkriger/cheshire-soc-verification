// ============================================================================
// chs_interrupt_test.sv — GPIO Interrupt Scenario Test
//
// Aşama 6: Verifies GPIO interrupt register configuration and the
// rising/falling edge detection mechanism via SBA register access.
// ============================================================================

`ifndef CHS_INTERRUPT_TEST_SV
`define CHS_INTERRUPT_TEST_SV

class chs_interrupt_test extends chs_base_test;

    `uvm_component_utils(chs_interrupt_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 100ms;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "========== GPIO Interrupt Test ==========", UVM_LOW)
        `uvm_info(get_type_name(), "Testing: Interrupt register config, rising/falling edge, W1C", UVM_LOW)
    endfunction

    virtual task test_body();
        chs_interrupt_vseq vseq;
        vseq = chs_interrupt_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);
        `uvm_info(get_type_name(), "========== Interrupt Test Complete ==========", UVM_LOW)
    endtask

endclass

`endif // CHS_INTERRUPT_TEST_SV

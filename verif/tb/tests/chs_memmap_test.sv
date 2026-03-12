// ============================================================================
// chs_memmap_test.sv — Memory Map Validation Test
//
// Aşama 7: Validates the Cheshire SoC memory map by reading from
// all known peripheral base addresses, boot ROM, CLINT, PLIC, DRAM.
// ============================================================================

`ifndef CHS_MEMMAP_TEST_SV
`define CHS_MEMMAP_TEST_SV

class chs_memmap_test extends chs_base_test;

    `uvm_component_utils(chs_memmap_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 50ms;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "========== Memory Map Validation Test ==========", UVM_LOW)
    endfunction

    virtual task test_body();
        chs_memmap_vseq vseq;
        vseq = chs_memmap_vseq::type_id::create("vseq");
        vseq.start(m_env.m_virt_sqr);
        `uvm_info(get_type_name(), "========== Memory Map Test Complete ==========", UVM_LOW)
    endtask

endclass

`endif // CHS_MEMMAP_TEST_SV

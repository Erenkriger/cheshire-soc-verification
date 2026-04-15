`ifndef CHS_SW_EXTERNAL_TEST_SV
`define CHS_SW_EXTERNAL_TEST_SV

// ============================================================================
// chs_sw_external_test.sv — Generic SW-driven UVM test for external C binaries
//
// Usage example:
//   make -C verif sim TEST=chs_sw_external_test \
//     PLUSARGS='+SW_WORDS_FILE=../sw/build/test_memmap_sweep.words +SW_TEST_NAME=test_memmap_sweep'
// ============================================================================

class chs_sw_external_test extends chs_base_test;

    `uvm_component_utils(chs_sw_external_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 500ms; // Extended Watchdog for Extreme Benchmark!
    endfunction

    virtual task test_body();
        chs_sw_driven_vseq vseq;
        string words_file;
        string sw_name;
        int timeout_cycles;

        if (!$value$plusargs("SW_WORDS_FILE=%s", words_file)) begin
            `uvm_fatal(get_type_name(),
                "Missing +SW_WORDS_FILE=<path>. Build with verif/sw make all to generate .words files.")
        end

        vseq = chs_sw_driven_vseq::type_id::create("vseq");
        vseq.program_words_file = words_file;

        if ($value$plusargs("SW_TEST_NAME=%s", sw_name))
            vseq.test_name = sw_name;
        else
            vseq.test_name = words_file;

        if ($value$plusargs("SW_TIMEOUT_CYCLES=%d", timeout_cycles))
            vseq.timeout_cycles = timeout_cycles;
        else
            vseq.timeout_cycles = 300000;

        `uvm_info(get_type_name(), $sformatf(
            "===== SW External Test START: %s (%s) =====",
            vseq.test_name, vseq.program_words_file), UVM_LOW)

        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(), "===== SW External Test COMPLETE =====", UVM_LOW)
    endtask

endclass : chs_sw_external_test

`endif // CHS_SW_EXTERNAL_TEST_SV

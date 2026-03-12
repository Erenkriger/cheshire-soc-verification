// ============================================================================
// chs_memmap_vseq.sv — Memory Map Validation Virtual Sequence
//
// Aşama 7: Systematically validates the Cheshire SoC memory map by
// accessing the base address of every peripheral via SBA and verifying
// the bus transaction completes without error.
//
// Tests:
//   1. Read from all known peripheral base addresses
//   2. Read from Boot ROM base address
//   3. Read from CLINT and PLIC base
//   4. Peripheral boundary addresses (first + last register)
//
// NOTE: DRAM is NOT tested here — it causes DMI BUSY cascade in sim.
//       DRAM write/read is validated by chs_periph_stress_test instead.
// ============================================================================

`ifndef CHS_MEMMAP_VSEQ_SV
`define CHS_MEMMAP_VSEQ_SV

class chs_memmap_vseq extends uvm_sequence;

    `uvm_object_utils(chs_memmap_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_memmap_vseq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq jtag_seq;
        bit [31:0]    idcode, rdata, sbcs_val;
        int           pass_cnt = 0;
        int           fail_cnt = 0;
        int           total = 0;

        `uvm_info(get_type_name(),
            "========== Memory Map Validation Test START ==========", UVM_LOW)

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // ── Initialize ──
        jtag_seq.do_reset(p_sequencer.m_jtag_sqr);
        jtag_seq.do_ir_scan(jtag_base_seq::IR_IDCODE, p_sequencer.m_jtag_sqr);
        jtag_seq.do_dr_scan(32'h0, 32, idcode, p_sequencer.m_jtag_sqr);
        `uvm_info(get_type_name(), $sformatf("IDCODE = 0x%08h", idcode), UVM_LOW)
        jtag_seq.sba_init(p_sequencer.m_jtag_sqr);

        // ════════════════════════════════════════════════════════════
        // Phase 1: Peripheral Base Address Probe
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[1/5] Peripheral Base Address Probe", UVM_LOW)
        begin
            // Peripherals to probe: {name, base_address}
            typedef struct {
                string       name;
                bit [31:0]   addr;
            } periph_entry_t;

            periph_entry_t periphs[7];
            periphs[0] = '{"Cheshire Regs", 32'h0300_0000};
            periphs[1] = '{"LLC Config",    32'h0300_1000};
            periphs[2] = '{"UART",          32'h0300_2000};
            periphs[3] = '{"I2C",           32'h0300_3000};
            periphs[4] = '{"SPI Host",      32'h0300_4000};
            periphs[5] = '{"GPIO",          32'h0300_5000};
            periphs[6] = '{"Serial Link",   32'h0300_6000};

            foreach (periphs[i]) begin
                total++;
                jtag_seq.sba_read32(periphs[i].addr, rdata, p_sequencer.m_jtag_sqr);

                // Check SBCS for error
                jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);

                if (sbcs_val[14:12] == 0) begin
                    `uvm_info(get_type_name(), $sformatf("  ✓ %-15s [0x%08h] = 0x%08h",
                        periphs[i].name, periphs[i].addr, rdata), UVM_LOW)
                    pass_cnt++;
                end else begin
                    `uvm_info(get_type_name(), $sformatf("  ✗ %-15s [0x%08h] SBA error=%0d",
                        periphs[i].name, periphs[i].addr, sbcs_val[14:12]), UVM_LOW)
                    fail_cnt++;
                    // Re-init SBA to clear error
                    jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
                end
            end
        end

        // ════════════════════════════════════════════════════════════
        // Phase 2: Boot ROM Access
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[2/5] Boot ROM Access", UVM_LOW)
        total++;
        jtag_seq.sba_read32(32'h0200_0000, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);
        if (sbcs_val[14:12] == 0) begin
            `uvm_info(get_type_name(), $sformatf("  ✓ Boot ROM [0x02000000] = 0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_info(get_type_name(), $sformatf("  ✗ Boot ROM SBA error=%0d", sbcs_val[14:12]), UVM_LOW)
            fail_cnt++;
            jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
        end

        // ════════════════════════════════════════════════════════════
        // Phase 3: CLINT Access
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[3/5] CLINT Access", UVM_LOW)
        total++;
        jtag_seq.sba_read32(32'h0204_0000, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);
        if (sbcs_val[14:12] == 0) begin
            `uvm_info(get_type_name(), $sformatf("  ✓ CLINT [0x02040000] = 0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_info(get_type_name(), $sformatf("  ✗ CLINT SBA error=%0d", sbcs_val[14:12]), UVM_LOW)
            fail_cnt++;
            jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
        end

        // ════════════════════════════════════════════════════════════
        // Phase 4: PLIC Access
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[4/5] PLIC Access", UVM_LOW)
        total++;
        jtag_seq.sba_read32(32'h0400_0000, rdata, p_sequencer.m_jtag_sqr);
        jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);
        if (sbcs_val[14:12] == 0) begin
            `uvm_info(get_type_name(), $sformatf("  ✓ PLIC [0x04000000] = 0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_info(get_type_name(), $sformatf("  ✗ PLIC SBA error=%0d", sbcs_val[14:12]), UVM_LOW)
            fail_cnt++;
            jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
        end

        // ════════════════════════════════════════════════════════════
        // Phase 5: Peripheral Register Boundaries
        // NOTE: DRAM is tested by chs_periph_stress_test. Skipped here
        //       because DRAM access can cause DMI BUSY cascade in sim.
        // ════════════════════════════════════════════════════════════
        `uvm_info(get_type_name(), "[5/5] Peripheral Register Boundaries", UVM_LOW)
        begin
            // Test first and last known registers in each peripheral
            typedef struct {
                string       name;
                bit [31:0]   addr;
            } boundary_t;

            boundary_t boundaries[8];
            boundaries[0] = '{"GPIO first (INTR_STATE)",   32'h0300_5000};
            boundaries[1] = '{"GPIO last  (CTRL_EN_FALL)", 32'h0300_5030};
            boundaries[2] = '{"UART first (RBR/THR)",      32'h0300_2000};
            boundaries[3] = '{"UART last  (SCR)",          32'h0300_201C};
            boundaries[4] = '{"SPI first  (INTR_STATE)",   32'h0300_4000};
            boundaries[5] = '{"SPI last   (ERR_ENABLE)",   32'h0300_4038};
            boundaries[6] = '{"I2C first  (INTR_STATE)",   32'h0300_3000};
            boundaries[7] = '{"I2C last   (TIMEOUT_CTRL)", 32'h0300_3044};

            foreach (boundaries[i]) begin
                total++;
                jtag_seq.sba_read32(boundaries[i].addr, rdata, p_sequencer.m_jtag_sqr);
                jtag_seq.dmi_read(7'h38, sbcs_val, p_sequencer.m_jtag_sqr);

                if (sbcs_val[14:12] == 0) begin
                    `uvm_info(get_type_name(), $sformatf("  ✓ %-30s [0x%08h] = 0x%08h",
                        boundaries[i].name, boundaries[i].addr, rdata), UVM_LOW)
                    pass_cnt++;
                end else begin
                    `uvm_info(get_type_name(), $sformatf("  ✗ %-30s [0x%08h] SBA error=%0d",
                        boundaries[i].name, boundaries[i].addr, sbcs_val[14:12]), UVM_LOW)
                    fail_cnt++;
                    jtag_seq.sba_init(p_sequencer.m_jtag_sqr);
                end
            end
        end

        // ─── Summary ───
        `uvm_info(get_type_name(), "========== Memory Map Validation Summary ==========", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Total: %0d  |  PASS: %0d  |  FAIL: %0d",
            total, pass_cnt, fail_cnt), UVM_LOW)
        if (fail_cnt > 0)
            `uvm_error(get_type_name(), $sformatf("Memory map test had %0d failures!", fail_cnt))
        else
            `uvm_info(get_type_name(), "Memory map validation PASSED ✓", UVM_LOW)
    endtask
endclass

`endif // CHS_MEMMAP_VSEQ_SV

// ============================================================================
// chs_ral_frontdoor_seq.sv — Custom Front-Door Sequence for RAL
//
// Since our bus access path (JTAG → DMI → SBA → AXI) requires
// multiple JTAG transactions for a single bus read/write, we use a
// custom frontdoor sequence that encapsulates the full SBA protocol.
//
// NOTE: This file is included by chs_seq_pkg (NOT chs_ral_pkg)
//       because it depends on jtag_base_seq which is defined in chs_seq_pkg.
// ============================================================================

`ifndef CHS_RAL_FRONTDOOR_SEQ_SV
`define CHS_RAL_FRONTDOOR_SEQ_SV

class chs_ral_frontdoor_seq extends uvm_reg_frontdoor;
    `uvm_object_utils(chs_ral_frontdoor_seq)

    function new(string name = "chs_ral_frontdoor_seq");
        super.new(name);
    endfunction

    virtual task body();
        jtag_base_seq  jtag_seq;
        bit [31:0]     addr;
        bit [31:0]     data;
        bit [31:0]     rdata;

        jtag_seq = jtag_base_seq::type_id::create("jtag_seq");

        // UVM 1.1d: use rw_info (not get_reg_item)
        addr = rw_info.offset[31:0];
        data = rw_info.value[0][31:0];

        if (rw_info.kind == UVM_WRITE) begin
            `uvm_info("RAL_FD", $sformatf("Front-door WRITE: [0x%08h] = 0x%08h", addr, data), UVM_HIGH)
            jtag_seq.sba_write32(addr, data, get_sequencer());
            rw_info.value[0] = data;
        end
        else begin
            `uvm_info("RAL_FD", $sformatf("Front-door READ: [0x%08h]", addr), UVM_HIGH)
            jtag_seq.sba_read32(addr, rdata, get_sequencer());
            rw_info.value[0] = rdata;
            `uvm_info("RAL_FD", $sformatf("Front-door READ result: 0x%08h", rdata), UVM_HIGH)
        end
    endtask
endclass

`endif // CHS_RAL_FRONTDOOR_SEQ_SV

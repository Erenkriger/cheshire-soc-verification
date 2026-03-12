// ============================================================================
// chs_ral_adapter.sv — RAL-to-SBA Bus Adapter
//
// Converts UVM RAL front-door read/write transactions into
// JTAG→SBA bus operations using the jtag_base_seq helper tasks.
//
// Architecture:
//   RAL model.write(addr, data)
//     → adapter.reg2bus()  → jtag_transaction (SBA write)
//     → adapter.bus2reg()  → status back to RAL
//
// This adapter implements uvm_reg_adapter and uses a special
// "SBA predictor" approach: since JTAG→SBA is multi-transaction
// (IR scan + DMI writes + idle), we wrap the entire SBA sequence
// in a single adapter call.
// ============================================================================

`ifndef CHS_RAL_ADAPTER_SV
`define CHS_RAL_ADAPTER_SV

class chs_ral_adapter extends uvm_reg_adapter;
    `uvm_object_utils(chs_ral_adapter)

    function new(string name = "chs_ral_adapter");
        super.new(name);
        // Tell RAL we support byte enables and provide responses
        supports_byte_enable = 0;
        provides_responses   = 1;
    endfunction

    // ────────────────────────────────────────────────────────────
    //  reg2bus: Convert a RAL register operation into a JTAG txn
    // ────────────────────────────────────────────────────────────
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        jtag_transaction txn;
        txn = jtag_transaction::type_id::create("ral_txn");

        // Encode the SBA operation in the JTAG transaction fields:
        //   ir_value[4]   = 1 → marks this as a RAL/SBA operation
        //   ir_value[0]   = 0 → write, 1 → read
        //   dr_value[31:0] = address
        //   dr_value[63:32] = write data (for writes)
        txn.op          = jtag_transaction::JTAG_DR_SCAN;
        txn.dr_length   = 64;
        txn.dr_value    = {rw.data[31:0], rw.addr[31:0]};
        txn.ir_value    = {1'b1, 3'b0, (rw.kind == UVM_READ) ? 1'b1 : 1'b0};
        txn.idle_cycles = 0;

        `uvm_info("RAL_ADAPTER",
            $sformatf("reg2bus: %s addr=0x%08h data=0x%08h",
                      (rw.kind == UVM_READ) ? "READ" : "WRITE",
                      rw.addr, rw.data), UVM_HIGH)

        return txn;
    endfunction

    // ────────────────────────────────────────────────────────────
    //  bus2reg: Convert the JTAG response back to RAL format
    // ────────────────────────────────────────────────────────────
    virtual function void bus2reg(uvm_sequence_item bus_item,
                                  ref uvm_reg_bus_op rw);
        jtag_transaction txn;
        if (!$cast(txn, bus_item)) begin
            `uvm_fatal("RAL_ADAPTER", "bus2reg: cast failed")
        end

        rw.data   = txn.dr_rdata;
        rw.status = UVM_IS_OK;

        `uvm_info("RAL_ADAPTER",
            $sformatf("bus2reg: data=0x%08h status=OK", rw.data), UVM_HIGH)
    endfunction

endclass

`endif // CHS_RAL_ADAPTER_SV

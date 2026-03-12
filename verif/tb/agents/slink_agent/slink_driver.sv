// ============================================================================
// slink_driver.sv — Serial Link Driver
// Drives rcv_clk_i and data_i lanes into DUT for RX path testing.
// ============================================================================

`ifndef SLINK_DRIVER_SV
`define SLINK_DRIVER_SV

class slink_driver extends uvm_driver #(slink_transaction);

    virtual slink_if vif;
    slink_config     m_cfg;

    `uvm_component_utils(slink_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual slink_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Serial Link virtual interface not found")
        if (!uvm_config_db#(slink_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "Serial Link config not found")
    endfunction

    task run_phase(uvm_phase phase);
        slink_transaction txn;

        // Initialize
        vif.rcv_clk_i <= '0;
        vif.data_i    <= '0;

        forever begin
            seq_item_port.get_next_item(txn);
            drive_transaction(txn);
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(slink_transaction txn);
        case (txn.op)
            slink_transaction::SLINK_TX: begin
                // Drive data from TB → DUT (RX path)
                foreach (txn.payload[i]) begin
                    // Drive lower nibble
                    @(posedge vif.clk);
                    vif.data_i[0] <= txn.payload[i][3:0];
                    vif.rcv_clk_i[0] <= 1'b1;
                    @(posedge vif.clk);
                    // Drive upper nibble
                    vif.data_i[0] <= txn.payload[i][7:4];
                    vif.rcv_clk_i[0] <= 1'b0;
                end
                @(posedge vif.clk);
                vif.data_i    <= '0;
                vif.rcv_clk_i <= '0;
            end

            slink_transaction::SLINK_IDLE: begin
                repeat (txn.num_beats) @(posedge vif.clk);
            end

            default: begin
                @(posedge vif.clk);
            end
        endcase
    endtask

endclass : slink_driver

`endif // SLINK_DRIVER_SV

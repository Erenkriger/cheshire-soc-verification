`ifndef SPI_BASE_SEQ_SV
`define SPI_BASE_SEQ_SV

// ============================================================================
// spi_base_seq.sv — Base SPI Sequence
// Provides reusable helper tasks:
//   - send_byte, send_cmd_addr, read_bytes
// ============================================================================

class spi_base_seq extends uvm_sequence #(spi_transaction);

    `uvm_object_utils(spi_base_seq)

    function new(string name = "spi_base_seq");
        super.new(name);
    endfunction

    // ========================== Helper Tasks ==========================

    // ---- Send Single Byte ----
    virtual task send_byte(bit [7:0] data, uvm_sequencer_base sqr = null);
        spi_transaction txn;
        txn = spi_transaction::type_id::create("txn_byte");
        start_item(txn, -1, sqr);
        txn.mode    = spi_transaction::SPI_STANDARD;
        txn.data    = new[1];
        txn.data[0] = data;
        txn.csb_sel = 2'b00;
        txn.cpol    = 0;
        txn.cpha    = 0;
        finish_item(txn);
        `uvm_info(get_type_name(), $sformatf("SPI TX byte: 0x%02h", data), UVM_HIGH)
    endtask : send_byte

    // ---- Send Command + 3-Byte Address (Flash Protocol) ----
    virtual task send_cmd_addr(bit [7:0] cmd, bit [23:0] addr,
                               uvm_sequencer_base sqr = null);
        spi_transaction txn;
        txn = spi_transaction::type_id::create("txn_cmd_addr");
        start_item(txn, -1, sqr);
        txn.mode    = spi_transaction::SPI_STANDARD;
        txn.data    = new[4];
        txn.data[0] = cmd;
        txn.data[1] = addr[23:16];
        txn.data[2] = addr[15:8];
        txn.data[3] = addr[7:0];
        txn.csb_sel = 2'b00;
        txn.cpol    = 0;
        txn.cpha    = 0;
        finish_item(txn);
        `uvm_info(get_type_name(),
                  $sformatf("SPI cmd+addr: cmd=0x%02h addr=0x%06h", cmd, addr), UVM_MEDIUM)
    endtask : send_cmd_addr

    // ---- Read N Bytes (Sends Dummy 0xFF) ----
    virtual task read_bytes(int count, uvm_sequencer_base sqr = null);
        spi_transaction txn;
        txn = spi_transaction::type_id::create("txn_read");
        start_item(txn, -1, sqr);
        txn.mode    = spi_transaction::SPI_STANDARD;
        txn.data    = new[count];
        for (int i = 0; i < count; i++)
            txn.data[i] = 8'hFF;
        txn.csb_sel = 2'b00;
        txn.cpol    = 0;
        txn.cpha    = 0;
        finish_item(txn);
        `uvm_info(get_type_name(),
                  $sformatf("SPI read %0d bytes (dummy 0xFF)", count), UVM_MEDIUM)
    endtask : read_bytes

    // ========================== Default body ==========================
    virtual task body();
        `uvm_info(get_type_name(), "spi_base_seq — default body (no-op)", UVM_LOW)
    endtask : body

endclass : spi_base_seq

`endif // SPI_BASE_SEQ_SV

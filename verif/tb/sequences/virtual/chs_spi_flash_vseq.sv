`ifndef CHS_SPI_FLASH_VSEQ_SV
`define CHS_SPI_FLASH_VSEQ_SV

// ============================================================================
// chs_spi_flash_vseq.sv — SPI Flash Read Virtual Sequence
// Simulates a flash read command sequence:
//   1. Send JEDEC Read ID command (0x9F)
//   2. Send Read Data command (0x03) + 24-bit address
//   3. Read back data bytes
// ============================================================================

class chs_spi_flash_vseq extends uvm_sequence;

    `uvm_object_utils(chs_spi_flash_vseq)
    `uvm_declare_p_sequencer(chs_virtual_sequencer)

    function new(string name = "chs_spi_flash_vseq");
        super.new(name);
    endfunction

    virtual task body();
        spi_base_seq spi_seq;

        `uvm_info(get_type_name(),
                  "===== SPI Flash Read START =====", UVM_LOW)

        spi_seq = spi_base_seq::type_id::create("spi_seq");

        // Step 1: JEDEC Read ID (cmd=0x9F, then read 3 bytes)
        `uvm_info(get_type_name(), "[1/3] JEDEC Read ID (0x9F)", UVM_MEDIUM)
        spi_seq.send_byte(8'h9F, p_sequencer.m_spi_sqr);
        spi_seq.read_bytes(3, p_sequencer.m_spi_sqr);

        // Step 2: Read Data cmd (0x03) + address 0x000000
        `uvm_info(get_type_name(), "[2/3] Flash Read (cmd=0x03, addr=0x000000)", UVM_MEDIUM)
        spi_seq.send_cmd_addr(8'h03, 24'h00_0000, p_sequencer.m_spi_sqr);

        // Step 3: Read 8 data bytes
        `uvm_info(get_type_name(), "[3/3] Reading 8 data bytes", UVM_MEDIUM)
        spi_seq.read_bytes(8, p_sequencer.m_spi_sqr);

        `uvm_info(get_type_name(),
                  "===== SPI Flash Read COMPLETE =====", UVM_LOW)
    endtask : body

endclass : chs_spi_flash_vseq

`endif

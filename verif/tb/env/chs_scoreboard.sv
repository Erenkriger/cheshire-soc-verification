`ifndef CHS_SCOREBOARD_SV
`define CHS_SCOREBOARD_SV

// ============================================================================
// chs_scoreboard.sv — Cheshire SoC Scoreboard
//
// Enhanced for Asama 3: Beyond simple counting, now performs:
//   - Expected vs actual data comparison for SPI, UART, GPIO
//   - Error flagging on mismatch
//   - Pass/fail statistics in report_phase
// ============================================================================

`uvm_analysis_imp_decl(_jtag)
`uvm_analysis_imp_decl(_uart)
`uvm_analysis_imp_decl(_spi)
`uvm_analysis_imp_decl(_i2c)
`uvm_analysis_imp_decl(_gpio)
`uvm_analysis_imp_decl(_axi)

class chs_scoreboard extends uvm_scoreboard;

    // ---------- Analysis imports ----------
    uvm_analysis_imp_jtag #(jtag_transaction, chs_scoreboard) jtag_imp;
    uvm_analysis_imp_uart #(uart_transaction, chs_scoreboard) uart_imp;
    uvm_analysis_imp_spi  #(spi_transaction,  chs_scoreboard) spi_imp;
    uvm_analysis_imp_i2c  #(i2c_transaction,  chs_scoreboard) i2c_imp;
    uvm_analysis_imp_gpio #(gpio_transaction, chs_scoreboard) gpio_imp;
    uvm_analysis_imp_axi  #(chs_axi_seq_item, chs_scoreboard) axi_imp;

    // ---------- Transaction counters ----------
    int unsigned jtag_tx_count;
    int unsigned uart_tx_count;
    int unsigned spi_tx_count;
    int unsigned i2c_tx_count;
    int unsigned gpio_tx_count;
    int unsigned axi_write_count;
    int unsigned axi_read_count;
    int unsigned axi_error_count;
    int unsigned axi_raw_match;
    int unsigned axi_raw_mismatch;

    // ---------- Verification counters ----------
    int unsigned uart_match_count;
    int unsigned uart_mismatch_count;
    int unsigned spi_match_count;
    int unsigned spi_mismatch_count;
    int unsigned gpio_match_count;
    int unsigned gpio_mismatch_count;

    // ---------- Expected value queues ----------
    // Tests push expected values; write_xxx() pops and compares
    bit [7:0]  expected_uart_data[$];
    bit [7:0]  expected_spi_mosi[$][$];   // Queue of byte arrays (per transfer)
    bit [31:0] expected_gpio_output[$];
    bit [31:0] expected_gpio_enable[$];

    // ---------- UART character buffer ----------
    string uart_char_buf;

    `uvm_component_utils(chs_scoreboard)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        jtag_imp = new("jtag_imp", this);
        uart_imp = new("uart_imp", this);
        spi_imp  = new("spi_imp",  this);
        i2c_imp  = new("i2c_imp",  this);
        gpio_imp = new("gpio_imp", this);
        axi_imp  = new("axi_imp",  this);

        jtag_tx_count     = 0;
        uart_tx_count     = 0;
        spi_tx_count      = 0;
        i2c_tx_count      = 0;
        gpio_tx_count     = 0;
        axi_write_count   = 0;
        axi_read_count    = 0;
        axi_error_count   = 0;
        axi_raw_match     = 0;
        axi_raw_mismatch  = 0;

        uart_match_count     = 0;
        uart_mismatch_count  = 0;
        spi_match_count      = 0;
        spi_mismatch_count   = 0;
        gpio_match_count     = 0;
        gpio_mismatch_count  = 0;

        uart_char_buf = "";
    endfunction

    // ========================== Expected Value Push API ==========================
    // Tests call these to set what the scoreboard should expect

    // Push expected UART TX byte (will be compared against monitor capture)
    function void expect_uart_byte(bit [7:0] data);
        expected_uart_data.push_back(data);
        `uvm_info("SCB_EXP", $sformatf("Expected UART byte queued: 0x%02h (queue=%0d)",
            data, expected_uart_data.size()), UVM_HIGH)
    endfunction

    // Push expected SPI MOSI bytes for one transfer
    function void expect_spi_transfer(bit [7:0] mosi_bytes[$]);
        expected_spi_mosi.push_back(mosi_bytes);
        `uvm_info("SCB_EXP", $sformatf("Expected SPI transfer queued: %0d bytes (queue=%0d)",
            mosi_bytes.size(), expected_spi_mosi.size()), UVM_HIGH)
    endfunction

    // Push expected GPIO output value
    function void expect_gpio_output(bit [31:0] output_val, bit [31:0] enable_val);
        expected_gpio_output.push_back(output_val);
        expected_gpio_enable.push_back(enable_val);
        `uvm_info("SCB_EXP", $sformatf("Expected GPIO queued: out=0x%08h en=0x%08h (queue=%0d)",
            output_val, enable_val, expected_gpio_output.size()), UVM_HIGH)
    endfunction

    // ========================== JTAG ==========================
    function void write_jtag(jtag_transaction tr);
        jtag_tx_count++;
        `uvm_info("SCB_JTAG", $sformatf("JTAG TR #%0d: op=%s ir=0x%02h dr=0x%08h dr_len=%0d",
            jtag_tx_count, tr.op.name(), tr.ir_value, tr.dr_value, tr.dr_length), UVM_MEDIUM)
    endfunction

    // ========================== UART ==========================
    function void write_uart(uart_transaction tr);
        byte c;
        uart_tx_count++;

        // Accumulate printable characters into buffer
        c = byte'(tr.data);
        if (c >= 8'h20 && c <= 8'h7e)
            uart_char_buf = {uart_char_buf, string'(c)};
        else if (c == 8'h0a || c == 8'h0d) begin
            if (uart_char_buf.len() > 0) begin
                `uvm_info("SCB_UART_LINE", $sformatf("UART RX line: \"%s\"",
                    uart_char_buf), UVM_LOW)
                uart_char_buf = "";
            end
        end

        `uvm_info("SCB_UART", $sformatf(
            "UART TR #%0d: dir=%s data=0x%02h '%c' parity_err=%0b frame_err=%0b",
            uart_tx_count, tr.direction.name(), tr.data,
            (tr.data >= 8'h20 && tr.data <= 8'h7e) ? tr.data : 8'h2e,
            tr.parity_error, tr.frame_error), UVM_MEDIUM)

        // ─── Expected value comparison ───
        if (expected_uart_data.size() > 0) begin
            bit [7:0] exp_data;
            exp_data = expected_uart_data.pop_front();
            if (tr.data === exp_data) begin
                uart_match_count++;
                `uvm_info("SCB_UART_CHK", $sformatf(
                    "UART MATCH: expected=0x%02h actual=0x%02h [OK]",
                    exp_data, tr.data), UVM_LOW)
            end else begin
                uart_mismatch_count++;
                `uvm_error("SCB_UART_CHK", $sformatf(
                    "UART MISMATCH: expected=0x%02h actual=0x%02h [FAIL]",
                    exp_data, tr.data))
            end
        end

        // Frame error check
        if (tr.frame_error)
            `uvm_warning("SCB_UART", $sformatf("UART frame error on byte 0x%02h", tr.data))
        if (tr.parity_error)
            `uvm_warning("SCB_UART", $sformatf("UART parity error on byte 0x%02h", tr.data))
    endfunction

    // ========================== SPI ==========================
    function void write_spi(spi_transaction tr);
        string data_str;
        spi_tx_count++;

        // Build MOSI data string for logging
        data_str = "";
        foreach (tr.mosi_data[i])
            data_str = {data_str, $sformatf("0x%02h ", tr.mosi_data[i])};

        `uvm_info("SCB_SPI", $sformatf(
            "SPI TR #%0d: mode=%s csb=%0d mosi_len=%0d miso_len=%0d data=[%s]",
            spi_tx_count, tr.mode.name(), tr.csb_sel,
            tr.mosi_data.size(), tr.miso_data.size(), data_str), UVM_MEDIUM)

        // ─── Expected value comparison ───
        if (expected_spi_mosi.size() > 0) begin
            bit [7:0] exp_bytes[$];
            int match;
            exp_bytes = expected_spi_mosi.pop_front();

            if (exp_bytes.size() != tr.mosi_data.size()) begin
                spi_mismatch_count++;
                `uvm_error("SCB_SPI_CHK", $sformatf(
                    "SPI LENGTH MISMATCH: expected=%0d bytes, actual=%0d bytes",
                    exp_bytes.size(), tr.mosi_data.size()))
            end else begin
                match = 1;
                foreach (exp_bytes[i]) begin
                    if (exp_bytes[i] !== tr.mosi_data[i]) begin
                        match = 0;
                        `uvm_error("SCB_SPI_CHK", $sformatf(
                            "SPI DATA MISMATCH at byte[%0d]: expected=0x%02h actual=0x%02h",
                            i, exp_bytes[i], tr.mosi_data[i]))
                    end
                end
                if (match) begin
                    spi_match_count++;
                    `uvm_info("SCB_SPI_CHK", $sformatf(
                        "SPI MATCH: %0d bytes verified [OK]", exp_bytes.size()), UVM_LOW)
                end else begin
                    spi_mismatch_count++;
                end
            end
        end
    endfunction

    // ========================== I2C ==========================
    function void write_i2c(i2c_transaction tr);
        i2c_tx_count++;
        `uvm_info("SCB_I2C", $sformatf("I2C TR #%0d: op=%s addr=0x%02h data_len=%0d ack=%0b",
            i2c_tx_count, tr.op.name(), tr.slave_addr,
            tr.data.size(), tr.ack_received), UVM_MEDIUM)
    endfunction

    // ========================== GPIO ==========================
    function void write_gpio(gpio_transaction tr);
        gpio_tx_count++;
        `uvm_info("SCB_GPIO", $sformatf(
            "GPIO TR #%0d: op=%s data=0x%08h mask=0x%08h out=0x%08h en=0x%08h",
            gpio_tx_count, tr.op.name(), tr.data, tr.mask,
            tr.observed_output, tr.observed_en), UVM_MEDIUM)

        // ─── Expected value comparison ───
        if (expected_gpio_output.size() > 0) begin
            bit [31:0] exp_out, exp_en;
            exp_out = expected_gpio_output.pop_front();
            exp_en  = expected_gpio_enable.pop_front();

            if (tr.observed_output === exp_out && tr.observed_en === exp_en) begin
                gpio_match_count++;
                `uvm_info("SCB_GPIO_CHK", $sformatf(
                    "GPIO MATCH: out=0x%08h en=0x%08h [OK]", exp_out, exp_en), UVM_LOW)
            end else begin
                gpio_mismatch_count++;
                `uvm_error("SCB_GPIO_CHK", $sformatf(
                    "GPIO MISMATCH: exp_out=0x%08h act_out=0x%08h exp_en=0x%08h act_en=0x%08h",
                    exp_out, tr.observed_output, exp_en, tr.observed_en))
            end
        end
    endfunction

    // ========================== AXI ==========================
    // Byte-granular memory model for AXI read-after-write checking.
    // Handles partial writes (e.g., 32-bit SBA write on 64-bit AXI bus)
    // by merging bytes via wstrb / size masking into 8-byte aligned words.
    bit [63:0] axi_mem_model [bit [47:0]];   // keyed by 8-byte aligned addr
    bit [7:0]  axi_mem_valid [bit [47:0]];   // validity bitmap per word (1 bit per byte)

    // Align an address to 64-bit (8-byte) AXI data word boundary
    function bit [47:0] axi_align8(bit [47:0] addr);
        return addr & ~48'h7;
    endfunction

    // Build a byte mask for a given beat address and access size
    function bit [7:0] axi_byte_mask(bit [47:0] beat_addr, bit [2:0] size);
        int num_bytes = 1 << size;
        int byte_off  = beat_addr[2:0];
        bit [7:0] mask = '0;
        for (int b = 0; b < num_bytes && (byte_off + b) < 8; b++)
            mask[byte_off + b] = 1'b1;
        return mask;
    endfunction

    function void write_axi(chs_axi_seq_item tr);
        string region;
        region = tr.get_region();

        if (tr.rw == chs_axi_seq_item::AXI_WRITE) begin
            axi_write_count++;

            // Merge write data into byte-granular memory model using strobe/size
            for (int i = 0; i <= tr.len && i < tr.wdata.size(); i++) begin
                bit [47:0] beat_addr = tr.addr + (i * (1 << tr.size));
                bit [47:0] aligned   = axi_align8(beat_addr);
                bit [7:0]  strb;

                // Use captured wstrb if available, otherwise derive from size
                if (i < tr.wstrb.size())
                    strb = tr.wstrb[i];
                else
                    strb = axi_byte_mask(beat_addr, tr.size);

                // Read-modify-write into aligned 64-bit word
                if (!axi_mem_model.exists(aligned)) begin
                    axi_mem_model[aligned] = 64'h0;
                    axi_mem_valid[aligned] = 8'h0;
                end

                for (int b = 0; b < 8; b++) begin
                    if (strb[b]) begin
                        axi_mem_model[aligned][b*8 +: 8] = tr.wdata[i][b*8 +: 8];
                        axi_mem_valid[aligned][b] = 1'b1;
                    end
                end
            end

            // Track errors
            if (tr.resp == 2'b10 || tr.resp == 2'b11) begin
                axi_error_count++;
                `uvm_warning("SCB_AXI", $sformatf(
                    "AXI WRITE ERROR: addr=0x%012h [%s] resp=%0d", tr.addr, region, tr.resp))
            end

            `uvm_info("SCB_AXI", $sformatf(
                "AXI WRITE #%0d: addr=0x%012h [%s] len=%0d resp=%0d latency=%0d",
                axi_write_count, tr.addr, region, tr.len, tr.resp, tr.latency_cycles), UVM_HIGH)

        end else begin
            axi_read_count++;

            // Compare read data against byte-granular memory model
            for (int i = 0; i <= tr.len && i < tr.rdata.size(); i++) begin
                bit [47:0] beat_addr = tr.addr + (i * (1 << tr.size));
                bit [47:0] aligned   = axi_align8(beat_addr);
                bit [7:0]  cmp_mask  = axi_byte_mask(beat_addr, tr.size);
                bit        beat_ok   = 1;

                if (axi_mem_model.exists(aligned)) begin
                    // Only compare bytes that were previously written (valid) AND
                    // that belong to this read beat (cmp_mask)
                    bit [7:0] eff_mask = cmp_mask & axi_mem_valid[aligned];

                    if (eff_mask == 8'h0) continue;  // No valid bytes to compare

                    for (int b = 0; b < 8; b++) begin
                        if (eff_mask[b]) begin
                            if (tr.rdata[i][b*8 +: 8] !== axi_mem_model[aligned][b*8 +: 8]) begin
                                beat_ok = 0;
                                break;
                            end
                        end
                    end

                    if (beat_ok) begin
                        axi_raw_match++;
                    end else begin
                        bit [63:0] exp_masked = 64'h0, got_masked = 64'h0;
                        for (int b = 0; b < 8; b++) begin
                            if (eff_mask[b]) begin
                                exp_masked[b*8 +: 8] = axi_mem_model[aligned][b*8 +: 8];
                                got_masked[b*8 +: 8] = tr.rdata[i][b*8 +: 8];
                            end
                        end
                        axi_raw_mismatch++;
                        `uvm_error("SCB_AXI", $sformatf(
                            "AXI RAW MISMATCH at 0x%012h [%s]: exp=0x%016h got=0x%016h (mask=0x%02h)",
                            beat_addr, region, exp_masked, got_masked, eff_mask))
                    end
                end
            end

            if (tr.resp == 2'b10 || tr.resp == 2'b11) begin
                axi_error_count++;
                `uvm_warning("SCB_AXI", $sformatf(
                    "AXI READ ERROR: addr=0x%012h [%s] resp=%0d", tr.addr, region, tr.resp))
            end

            `uvm_info("SCB_AXI", $sformatf(
                "AXI READ #%0d: addr=0x%012h [%s] len=%0d resp=%0d latency=%0d",
                axi_read_count, tr.addr, region, tr.len, tr.resp, tr.latency_cycles), UVM_HIGH)
        end
    endfunction

    // ========================== Report ==========================
    function void report_phase(uvm_phase phase);
        int unsigned total_checks, total_pass, total_fail;
        string status_str;

        super.report_phase(phase);

        total_pass  = uart_match_count + spi_match_count + gpio_match_count + axi_raw_match;
        total_fail  = uart_mismatch_count + spi_mismatch_count + gpio_mismatch_count + axi_raw_mismatch;
        total_checks = total_pass + total_fail;

        if (total_fail > 0)
            status_str = "*** FAIL ***";
        else if (total_checks > 0)
            status_str = "*** PASS ***";
        else
            status_str = "(no checks)";

        `uvm_info("SCB_SUMMARY", $sformatf({"\n",
            "============================================================\n",
            "  Cheshire SoC Scoreboard Summary          %s\n",
            "============================================================\n",
            "  JTAG transactions : %0d\n",
            "  UART transactions : %0d  (match=%0d mismatch=%0d)\n",
            "  SPI  transactions : %0d  (match=%0d mismatch=%0d)\n",
            "  I2C  transactions : %0d\n",
            "  GPIO transactions : %0d  (match=%0d mismatch=%0d)\n",
            "  AXI  writes       : %0d  reads=%0d  errors=%0d\n",
            "  AXI  RAW checks   : match=%0d mismatch=%0d\n",
            "------------------------------------------------------------\n",
            "  Total data checks : %0d  PASS=%0d  FAIL=%0d\n",
            "============================================================"},
            status_str,
            jtag_tx_count,
            uart_tx_count, uart_match_count, uart_mismatch_count,
            spi_tx_count,  spi_match_count,  spi_mismatch_count,
            i2c_tx_count,
            gpio_tx_count, gpio_match_count, gpio_mismatch_count,
            axi_write_count, axi_read_count, axi_error_count,
            axi_raw_match, axi_raw_mismatch,
            total_checks, total_pass, total_fail), UVM_LOW)

        // Print any remaining UART buffer content
        if (uart_char_buf.len() > 0) begin
            `uvm_info("SCB_UART_FINAL", $sformatf(
                "Remaining UART buffer: \"%s\"", uart_char_buf), UVM_LOW)
        end

        // Flag if expected values remain unconsumed
        if (expected_uart_data.size() > 0)
            `uvm_warning("SCB_UNMATCHED", $sformatf(
                "%0d expected UART bytes never received by monitor",
                expected_uart_data.size()))
        if (expected_spi_mosi.size() > 0)
            `uvm_warning("SCB_UNMATCHED", $sformatf(
                "%0d expected SPI transfers never received by monitor",
                expected_spi_mosi.size()))
        if (expected_gpio_output.size() > 0)
            `uvm_warning("SCB_UNMATCHED", $sformatf(
                "%0d expected GPIO outputs never received by monitor",
                expected_gpio_output.size()))
    endfunction

endclass : chs_scoreboard

`endif // CHS_SCOREBOARD_SV

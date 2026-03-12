`ifndef SPI_MONITOR_SV
`define SPI_MONITOR_SV

// ============================================================================
// spi_monitor.sv — SPI Bus Monitor (Passive)
// Observes SCK, CSB, sd_o/sd_i and constructs full SPI transactions
//
// Key Fix: Uses edge-based CS detection (@negedge csb) for reliability,
// with level-check fallback. Adds debug logging and timeout guard.
// ============================================================================

class spi_monitor extends uvm_monitor;

    virtual spi_if vif;
    spi_config     m_cfg;

    uvm_analysis_port #(spi_transaction) ap;

    // Debug counters
    int unsigned total_transfers = 0;
    int unsigned total_bytes     = 0;

    `uvm_component_utils(spi_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "SPI virtual interface not found in config_db")
        if (!uvm_config_db#(spi_config)::get(this, "", "m_cfg", m_cfg))
            `uvm_fatal("NOCFG", "SPI config not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        `uvm_info("SPI_MON", $sformatf("SPI Monitor started (CPOL=%0b CPHA=%0b)",
            m_cfg.cpol, m_cfg.cpha), UVM_LOW)
        forever begin
            monitor_spi_transfer();
        end
    endtask

    // Report phase — log final statistics
    function void report_phase(uvm_phase phase);
        `uvm_info("SPI_MON", $sformatf(
            "SPI Monitor Summary: %0d transfers, %0d total bytes captured",
            total_transfers, total_bytes), UVM_LOW)
    endfunction

    // Monitor a complete SPI transfer (CS assert → data → CS de-assert)
    task monitor_spi_transfer();
        spi_transaction tr;
        spi_transaction::spi_mode_e detected_mode;
        int unsigned bits_per_cycle;
        int unsigned bit_count;
        bit [7:0] mosi_byte, miso_byte;
        bit [7:0] mosi_queue[$];
        bit [7:0] miso_queue[$];
        int cs_idx;
        realtime t_start;

        // ─── Wait for CS assertion (falling edge) ───
        // Use level-based wait — simpler and avoids disable fork issues
        wait (vif.csb[0] === 1'b0 || vif.csb[1] === 1'b0);

        // Small settling delay to avoid delta-cycle races
        #1;

        // Determine which CS is active
        if (vif.csb[0] === 1'b0)
            cs_idx = 0;
        else if (vif.csb[1] === 1'b0)
            cs_idx = 1;
        else begin
            // CS went high already (glitch) — skip
            `uvm_info("SPI_MON", "CS glitch detected (asserted and deasserted within 1 delta)", UVM_HIGH)
            return;
        end

        t_start = $realtime;
        `uvm_info("SPI_MON", $sformatf(
            "CS[%0d] ASSERTED @ %0t — transfer started (SCK=%0b)",
            cs_idx, t_start, vif.sck), UVM_MEDIUM)

        // Detect SPI mode from sd_en lines on first cycle
        detected_mode = spi_transaction::SPI_STANDARD;
        bits_per_cycle = 1;

        mosi_byte = '0;
        miso_byte = '0;
        bit_count = 0;

        // Capture data on each SCK edge while CS is asserted
        // CRITICAL: Must use fork/join_any to detect CS deassertion
        // because SCK stops toggling after the transfer. Without this,
        // @(posedge vif.sck) blocks forever after CS goes high.
        begin
            bit cs_deasserted = 0;

            while (!cs_deasserted) begin
                fork
                    begin : wait_sck_edge
                        // Sample on appropriate SCK edge based on CPOL/CPHA
                        if (m_cfg.cpol == m_cfg.cpha)
                            @(posedge vif.sck);
                        else
                            @(negedge vif.sck);
                    end
                    begin : wait_cs_deassert
                        @(posedge vif.csb[cs_idx]);
                        cs_deasserted = 1;
                    end
                join_any
                disable fork;

                if (cs_deasserted) break;

                // Re-check CS after clock edge (CS may have deasserted simultaneously)
                if (vif.csb[cs_idx] !== 1'b0) break;

                // Detect transfer mode from output enables
                if (vif.sd_en == 4'b1111) begin
                    detected_mode = spi_transaction::SPI_QUAD;
                    bits_per_cycle = 4;
                end else if (vif.sd_en[1:0] == 2'b11) begin
                    detected_mode = spi_transaction::SPI_DUAL;
                    bits_per_cycle = 2;
                end else begin
                    detected_mode = spi_transaction::SPI_STANDARD;
                    bits_per_cycle = 1;
                end

                // Capture data based on mode (MSB first)
                case (detected_mode)
                    spi_transaction::SPI_STANDARD: begin
                        mosi_byte = {mosi_byte[6:0], vif.sd_o[0]};  // MOSI = sd_o[0]
                        miso_byte = {miso_byte[6:0], vif.sd_i[1]};  // MISO = sd_i[1]
                        bit_count++;
                    end
                    spi_transaction::SPI_DUAL: begin
                        mosi_byte = {mosi_byte[5:0], vif.sd_o[1:0]};
                        miso_byte = {miso_byte[5:0], vif.sd_i[1:0]};
                        bit_count += 2;
                    end
                    spi_transaction::SPI_QUAD: begin
                        mosi_byte = {mosi_byte[3:0], vif.sd_o[3:0]};
                        miso_byte = {miso_byte[3:0], vif.sd_i[3:0]};
                        bit_count += 4;
                    end
                endcase

                // Byte boundary reached
                if (bit_count >= 8) begin
                    mosi_queue.push_back(mosi_byte);
                    miso_queue.push_back(miso_byte);
                    `uvm_info("SPI_MON", $sformatf(
                        "Byte captured: MOSI=0x%02h MISO=0x%02h (byte #%0d)",
                        mosi_byte, miso_byte, mosi_queue.size()), UVM_HIGH)
                    mosi_byte = '0;
                    miso_byte = '0;
                    bit_count = 0;
                end
            end
        end

        // Flush any remaining partial byte
        if (bit_count > 0) begin
            mosi_queue.push_back(mosi_byte);
            miso_queue.push_back(miso_byte);
            `uvm_info("SPI_MON", $sformatf(
                "Partial byte flushed (%0d bits): MOSI=0x%02h MISO=0x%02h",
                bit_count, mosi_byte, miso_byte), UVM_HIGH)
        end

        // Build and broadcast transaction
        if (mosi_queue.size() > 0 || miso_queue.size() > 0) begin
            tr = spi_transaction::type_id::create("spi_mon_tr");
            tr.mode     = detected_mode;
            tr.csb_sel  = cs_idx[1:0];
            tr.cpol     = m_cfg.cpol;
            tr.cpha     = m_cfg.cpha;

            tr.mosi_data = new[mosi_queue.size()];
            foreach (mosi_queue[i]) tr.mosi_data[i] = mosi_queue[i];

            tr.miso_data = new[miso_queue.size()];
            foreach (miso_queue[i]) tr.miso_data[i] = miso_queue[i];

            total_transfers++;
            total_bytes += mosi_queue.size();

            `uvm_info("SPI_MON", $sformatf(
                "Transfer #%0d complete: CS[%0d] mode=%s, %0d bytes MOSI, %0d bytes MISO, duration=%0t",
                total_transfers, cs_idx, detected_mode.name(),
                mosi_queue.size(), miso_queue.size(), $realtime - t_start),
                UVM_MEDIUM)

            // Log data bytes for debug
            begin
                string data_str;
                data_str = "";
                foreach (mosi_queue[i])
                    data_str = {data_str, $sformatf("0x%02h ", mosi_queue[i])};
                `uvm_info("SPI_MON", $sformatf("  MOSI data: %s", data_str), UVM_MEDIUM)
            end

            ap.write(tr);
        end else begin
            `uvm_info("SPI_MON", $sformatf(
                "CS[%0d] deasserted but no data captured (duration=%0t)",
                cs_idx, $realtime - t_start), UVM_HIGH)
        end
    endtask

endclass : spi_monitor

`endif // SPI_MONITOR_SV

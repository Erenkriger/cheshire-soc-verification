`ifndef CHS_AXI_SEQ_ITEM_SV
`define CHS_AXI_SEQ_ITEM_SV

// ============================================================================
// chs_axi_seq_item.sv — AXI4 UVM Sequence Item for Cheshire SoC
//
// Represents a single AXI read or write transaction observed on
// the LLC DRAM port. Used by the passive AXI monitor.
// ============================================================================

class chs_axi_seq_item extends uvm_sequence_item;

    // Transaction type
    typedef enum bit { AXI_READ = 1'b0, AXI_WRITE = 1'b1 } axi_rw_e;

    // Address phase fields
    rand axi_rw_e         rw;
    rand bit [47:0]       addr;
    rand bit [7:0]        id;
    rand bit [7:0]        len;        // burst length - 1
    rand bit [2:0]        size;       // 2^size bytes per beat
    rand bit [1:0]        burst;      // FIXED=0, INCR=1, WRAP=2
    rand bit              lock;
    rand bit [3:0]        cache;
    rand bit [2:0]        prot;
    rand bit [3:0]        qos;
    rand bit [5:0]        atop;       // AXI5 atomic ops (Cheshire uses ATOP)

    // Write data (collected across W beats)
    bit [63:0]            wdata[];
    bit [7:0]             wstrb[];

    // Read data (collected across R beats)
    bit [63:0]            rdata[];

    // Response
    bit [1:0]             resp;       // Final response (last beat for reads)

    // Timing metadata
    time                  start_time;
    time                  end_time;
    int unsigned          latency_cycles;

    `uvm_object_utils_begin(chs_axi_seq_item)
        `uvm_field_enum(axi_rw_e, rw,   UVM_ALL_ON)
        `uvm_field_int(addr,             UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(id,               UVM_ALL_ON)
        `uvm_field_int(len,              UVM_ALL_ON)
        `uvm_field_int(size,             UVM_ALL_ON)
        `uvm_field_int(burst,            UVM_ALL_ON)
        `uvm_field_int(lock,             UVM_ALL_ON)
        `uvm_field_int(cache,            UVM_ALL_ON)
        `uvm_field_int(prot,             UVM_ALL_ON)
        `uvm_field_int(qos,              UVM_ALL_ON)
        `uvm_field_int(atop,             UVM_ALL_ON)
        `uvm_field_int(resp,             UVM_ALL_ON)
        `uvm_field_int(latency_cycles,   UVM_ALL_ON)
        `uvm_field_array_int(wdata,      UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(wstrb,      UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(rdata,      UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "chs_axi_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        string s;
        s = $sformatf("AXI %s: addr=0x%012h id=%0d len=%0d size=%0d burst=%0d resp=%0d latency=%0d",
                       rw.name(), addr, id, len, size, burst, resp, latency_cycles);
        if (rw == AXI_WRITE && wdata.size() > 0)
            s = {s, $sformatf(" wdata[0]=0x%016h", wdata[0])};
        else if (rw == AXI_READ && rdata.size() > 0)
            s = {s, $sformatf(" rdata[0]=0x%016h", rdata[0])};
        return s;
    endfunction

    // Memory region classifier for Cheshire SoC
    function string get_region();
        if (addr >= 48'h0000_0000_0000 && addr < 48'h0000_0000_1000) return "DEBUG";
        if (addr >= 48'h0000_0200_0000 && addr < 48'h0000_0201_0000) return "BOOTROM";
        if (addr >= 48'h0000_0204_0000 && addr < 48'h0000_0208_0000) return "CLINT";
        if (addr >= 48'h0000_0300_0000 && addr < 48'h0000_0310_0000) return "PERIPHERALS";
        if (addr >= 48'h0000_0400_0000 && addr < 48'h0000_0800_0000) return "PLIC";
        if (addr >= 48'h0000_1400_0000 && addr < 48'h0000_1410_0000) return "LLC_SPM";
        if (addr >= 48'h0000_8000_0000 && addr < 48'h0000_C000_0000) return "DRAM";
        return "UNMAPPED";
    endfunction

endclass : chs_axi_seq_item

`endif // CHS_AXI_SEQ_ITEM_SV

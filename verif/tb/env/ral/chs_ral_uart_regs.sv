// ============================================================================
// chs_ral_uart_regs.sv — UART 16550 Register Block (RAL)
//
// Base: 0x0300_2000
// Registers modeled: THR/RBR, IER, FCR/IIR, LCR, MCR, LSR, DLL, DLM
// ============================================================================

`ifndef CHS_RAL_UART_REGS_SV
`define CHS_RAL_UART_REGS_SV

// ─── Individual Register Definitions ───

class chs_ral_uart_thr extends uvm_reg;
    `uvm_object_utils(chs_ral_uart_thr)

    rand uvm_reg_field data;

    function new(string name = "chs_ral_uart_thr");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        data = uvm_reg_field::type_id::create("data");
        data.configure(this, 8, 0, "WO", 0, 8'h0, 1, 1, 1);
    endfunction
endclass

class chs_ral_uart_ier extends uvm_reg;
    `uvm_object_utils(chs_ral_uart_ier)

    rand uvm_reg_field erbfi;  // Enable Received Data Available Interrupt
    rand uvm_reg_field etbei;  // Enable THR Empty Interrupt
    rand uvm_reg_field elsi;   // Enable Receiver Line Status Interrupt
    rand uvm_reg_field edssi;  // Enable Modem Status Interrupt

    function new(string name = "chs_ral_uart_ier");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        erbfi = uvm_reg_field::type_id::create("erbfi");
        erbfi.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
        etbei = uvm_reg_field::type_id::create("etbei");
        etbei.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
        elsi = uvm_reg_field::type_id::create("elsi");
        elsi.configure(this, 1, 2, "RW", 0, 1'b0, 1, 1, 0);
        edssi = uvm_reg_field::type_id::create("edssi");
        edssi.configure(this, 1, 3, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

class chs_ral_uart_fcr extends uvm_reg;
    `uvm_object_utils(chs_ral_uart_fcr)

    rand uvm_reg_field fifo_en;
    rand uvm_reg_field rx_fifo_rst;
    rand uvm_reg_field tx_fifo_rst;
    rand uvm_reg_field rx_trigger;

    function new(string name = "chs_ral_uart_fcr");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        fifo_en = uvm_reg_field::type_id::create("fifo_en");
        fifo_en.configure(this, 1, 0, "WO", 0, 1'b0, 1, 1, 0);
        rx_fifo_rst = uvm_reg_field::type_id::create("rx_fifo_rst");
        rx_fifo_rst.configure(this, 1, 1, "WO", 0, 1'b0, 1, 1, 0);
        tx_fifo_rst = uvm_reg_field::type_id::create("tx_fifo_rst");
        tx_fifo_rst.configure(this, 1, 2, "WO", 0, 1'b0, 1, 1, 0);
        rx_trigger = uvm_reg_field::type_id::create("rx_trigger");
        rx_trigger.configure(this, 2, 6, "WO", 0, 2'b0, 1, 1, 0);
    endfunction
endclass

class chs_ral_uart_lcr extends uvm_reg;
    `uvm_object_utils(chs_ral_uart_lcr)

    rand uvm_reg_field wls;    // Word Length Select (2 bits)
    rand uvm_reg_field stb;    // Number of Stop Bits
    rand uvm_reg_field pen;    // Parity Enable
    rand uvm_reg_field eps;    // Even Parity Select
    rand uvm_reg_field dlab;   // Divisor Latch Access Bit

    function new(string name = "chs_ral_uart_lcr");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        wls = uvm_reg_field::type_id::create("wls");
        wls.configure(this, 2, 0, "RW", 0, 2'b11, 1, 1, 0);  // 8-bit default
        stb = uvm_reg_field::type_id::create("stb");
        stb.configure(this, 1, 2, "RW", 0, 1'b0, 1, 1, 0);
        pen = uvm_reg_field::type_id::create("pen");
        pen.configure(this, 1, 3, "RW", 0, 1'b0, 1, 1, 0);
        eps = uvm_reg_field::type_id::create("eps");
        eps.configure(this, 1, 4, "RW", 0, 1'b0, 1, 1, 0);
        dlab = uvm_reg_field::type_id::create("dlab");
        dlab.configure(this, 1, 7, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

class chs_ral_uart_mcr extends uvm_reg;
    `uvm_object_utils(chs_ral_uart_mcr)

    rand uvm_reg_field dtr;
    rand uvm_reg_field rts;
    rand uvm_reg_field loopback;

    function new(string name = "chs_ral_uart_mcr");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        dtr = uvm_reg_field::type_id::create("dtr");
        dtr.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
        rts = uvm_reg_field::type_id::create("rts");
        rts.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
        loopback = uvm_reg_field::type_id::create("loopback");
        loopback.configure(this, 1, 4, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass

class chs_ral_uart_lsr extends uvm_reg;
    `uvm_object_utils(chs_ral_uart_lsr)

    uvm_reg_field dr;     // Data Ready
    uvm_reg_field oe;     // Overrun Error
    uvm_reg_field pe;     // Parity Error
    uvm_reg_field fe;     // Framing Error
    uvm_reg_field thre;   // THR Empty
    uvm_reg_field temt;   // Transmitter Empty

    function new(string name = "chs_ral_uart_lsr");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        dr   = uvm_reg_field::type_id::create("dr");
        dr.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);
        oe   = uvm_reg_field::type_id::create("oe");
        oe.configure(this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);
        pe   = uvm_reg_field::type_id::create("pe");
        pe.configure(this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
        fe   = uvm_reg_field::type_id::create("fe");
        fe.configure(this, 1, 3, "RO", 1, 1'b0, 1, 0, 0);
        thre = uvm_reg_field::type_id::create("thre");
        thre.configure(this, 1, 5, "RO", 1, 1'b1, 1, 0, 0);   // default=1 (empty)
        temt = uvm_reg_field::type_id::create("temt");
        temt.configure(this, 1, 6, "RO", 1, 1'b1, 1, 0, 0);   // default=1 (empty)
    endfunction
endclass

class chs_ral_uart_dll extends uvm_reg;
    `uvm_object_utils(chs_ral_uart_dll)

    rand uvm_reg_field dll;

    function new(string name = "chs_ral_uart_dll");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        dll = uvm_reg_field::type_id::create("dll");
        dll.configure(this, 8, 0, "RW", 0, 8'h01, 1, 1, 1);
    endfunction
endclass

class chs_ral_uart_dlm extends uvm_reg;
    `uvm_object_utils(chs_ral_uart_dlm)

    rand uvm_reg_field dlm;

    function new(string name = "chs_ral_uart_dlm");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        dlm = uvm_reg_field::type_id::create("dlm");
        dlm.configure(this, 8, 0, "RW", 0, 8'h00, 1, 1, 1);
    endfunction
endclass

// ─── UART Register Block ───

class chs_ral_uart_block extends uvm_reg_block;
    `uvm_object_utils(chs_ral_uart_block)

    // Registers
    rand chs_ral_uart_thr thr;    // 0x00 (DLAB=0 write)
    rand chs_ral_uart_ier ier;    // 0x04
    rand chs_ral_uart_fcr fcr;    // 0x08
    rand chs_ral_uart_lcr lcr;    // 0x0C
    rand chs_ral_uart_mcr mcr;    // 0x10
         chs_ral_uart_lsr lsr;    // 0x14
    rand chs_ral_uart_dll dll;    // 0x00 (DLAB=1)
    rand chs_ral_uart_dlm dlm;    // 0x04 (DLAB=1)

    uvm_reg_map default_map;

    function new(string name = "chs_ral_uart_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        // Create registers
        thr = chs_ral_uart_thr::type_id::create("thr");
        thr.configure(this, null, "");
        thr.build();

        ier = chs_ral_uart_ier::type_id::create("ier");
        ier.configure(this, null, "");
        ier.build();

        fcr = chs_ral_uart_fcr::type_id::create("fcr");
        fcr.configure(this, null, "");
        fcr.build();

        lcr = chs_ral_uart_lcr::type_id::create("lcr");
        lcr.configure(this, null, "");
        lcr.build();

        mcr = chs_ral_uart_mcr::type_id::create("mcr");
        mcr.configure(this, null, "");
        mcr.build();

        lsr = chs_ral_uart_lsr::type_id::create("lsr");
        lsr.configure(this, null, "");
        lsr.build();

        dll = chs_ral_uart_dll::type_id::create("dll");
        dll.configure(this, null, "");
        dll.build();

        dlm = chs_ral_uart_dlm::type_id::create("dlm");
        dlm.configure(this, null, "");
        dlm.build();

        // Create default map
        default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);

        // Add registers to map
        // Note: DLL/DLM share address with THR/IER (selected by DLAB bit in LCR).
        // RAL does not support address aliasing natively, so DLL/DLM are
        // placed at offset +0x100 as a convention. Tests must set DLAB=1
        // before using DLL/DLM and use raw SBA for those accesses.
        default_map.add_reg(thr, 'h00, "WO");
        default_map.add_reg(ier, 'h04, "RW");
        default_map.add_reg(fcr, 'h08, "WO");
        default_map.add_reg(lcr, 'h0C, "RW");
        default_map.add_reg(mcr, 'h10, "RW");
        default_map.add_reg(lsr, 'h14, "RO");

        lock_model();
    endfunction
endclass

`endif // CHS_RAL_UART_REGS_SV

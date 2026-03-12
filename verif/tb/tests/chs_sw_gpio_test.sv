`ifndef CHS_SW_GPIO_TEST_SV
`define CHS_SW_GPIO_TEST_SV

// ============================================================================
// chs_sw_gpio_test.sv — SW-Driven GPIO Test
//
// Loads a hand-assembled GPIO firmware into SPM via JTAG SBA, then lets
// the CVA6 execute it. The firmware writes several patterns to GPIO_OUT
// and signals EOC=PASS to SCRATCH[2].
//
// Full data path exercised:
//   JTAG → DMI → SBA → SPM → CVA6 pipeline → APB bus → GPIO registers
//
// This is a true "Software-Driven Verification" scenario — the DUT
// processor executes real firmware that drives its own peripherals.
// ============================================================================

class chs_sw_gpio_test extends chs_base_test;

    `uvm_component_utils(chs_sw_gpio_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_timeout = 50ms;
    endfunction

    virtual task test_body();
        chs_sw_driven_vseq vseq;

        `uvm_info(get_type_name(),
            "===== SW-Driven GPIO Test: Firmware GPIO Patterns =====", UVM_LOW)

        vseq = chs_sw_driven_vseq::type_id::create("vseq");
        vseq.test_name       = "sw_gpio_patterns";
        vseq.timeout_cycles  = 200000;

        // Build the GPIO test program
        build_gpio_program(vseq);

        vseq.start(m_env.m_virt_sqr);

        `uvm_info(get_type_name(),
            "===== SW-Driven GPIO Test COMPLETE =====", UVM_LOW)
    endtask : test_body

    // ════════════════════════════════════════════════════════════════
    // Hand-assembled GPIO test firmware (RV64I)
    //
    // Register allocation:
    //   x5  (t0) = temporary / pattern value
    //   x6  (t1) = GPIO_BASE = 0x03005000
    //   x30 (t5) = REGS_BASE = 0x03000000
    //
    // GPIO register offsets from GPIO_BASE:
    //   +0x08 = GPIO_OUTPUT_EN  (write 1 = output mode)
    //   +0x0C = GPIO_OUTPUT_VAL (write pattern here)
    //
    // SCRATCH[2] at REGS_BASE + 0x08 = 0x03000008
    //   Write (retval<<1)|1 to signal EOC; for pass: write 1
    //
    // Equivalent C:
    //   GPIO_OE  = 0xFFFFFFFF;
    //   GPIO_OUT = 0x01; GPIO_OUT = 0x02; GPIO_OUT = 0x04;
    //   GPIO_OUT = 0x00; GPIO_OUT = 0xFF;
    //   SCRATCH2 = 1;  // EOC pass (return code 0)
    //   while(1) wfi;
    // ════════════════════════════════════════════════════════════════
    virtual function void build_gpio_program(chs_sw_driven_vseq vseq);
        int i;

        vseq.program_image = new[18];
        i = 0;

        // ─── Setup base addresses ───
        vseq.program_image[i++] = 32'h03005337;   // lui   t1(x6), 0x03005     ; t1 = GPIO_BASE
        vseq.program_image[i++] = 32'h03000F37;   // lui   t5(x30), 0x03000    ; t5 = REGS_BASE

        // ─── GPIO_OE = 0xFFFFFFFF (enable all outputs) ───
        vseq.program_image[i++] = 32'hFFF00293;   // addi  t0(x5), x0, -1      ; t0 = 0xFFFFFFFF
        vseq.program_image[i++] = 32'h00532423;   // sw    t0, 8(t1)           ; GPIO_OE = all

        // ─── Pattern 1: GPIO_OUT = 0x01 ───
        vseq.program_image[i++] = 32'h00100293;   // addi  t0, x0, 1
        vseq.program_image[i++] = 32'h00532623;   // sw    t0, 12(t1)          ; GPIO_OUT

        // ─── Pattern 2: GPIO_OUT = 0x02 ───
        vseq.program_image[i++] = 32'h00200293;   // addi  t0, x0, 2
        vseq.program_image[i++] = 32'h00532623;   // sw    t0, 12(t1)

        // ─── Pattern 3: GPIO_OUT = 0x04 ───
        vseq.program_image[i++] = 32'h00400293;   // addi  t0, x0, 4
        vseq.program_image[i++] = 32'h00532623;   // sw    t0, 12(t1)

        // ─── Pattern 4: GPIO_OUT = 0x00 (all zeros) ───
        vseq.program_image[i++] = 32'h00000293;   // addi  t0, x0, 0
        vseq.program_image[i++] = 32'h00532623;   // sw    t0, 12(t1)

        // ─── Pattern 5: GPIO_OUT = 0xFF ───
        vseq.program_image[i++] = 32'h0FF00293;   // addi  t0, x0, 0xFF
        vseq.program_image[i++] = 32'h00532623;   // sw    t0, 12(t1)

        // ─── EOC: SCRATCH[2] = 1 (pass, exit_code=0) ───
        vseq.program_image[i++] = 32'h00100293;   // addi  t0, x0, 1           ; t0 = 1
        vseq.program_image[i++] = 32'h005F2423;   // sw    t0, 8(t5)           ; SCRATCH[2] = 1

        // ─── Infinite WFI loop ───
        vseq.program_image[i++] = 32'h10500073;   // wfi
        vseq.program_image[i++] = 32'hFFDFF06F;   // jal   x0, -4             ; loop back to wfi

        vseq.program_size = i;

        `uvm_info("SW_GPIO", $sformatf(
            "Built GPIO test program: %0d instructions (%0d bytes)",
            i, i*4), UVM_MEDIUM)

    endfunction : build_gpio_program

endclass : chs_sw_gpio_test

`endif // CHS_SW_GPIO_TEST_SV

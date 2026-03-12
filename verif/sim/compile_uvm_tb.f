// ============================================================================
// compile_uvm_tb.f — UVM Testbench File List
//
// Usage (QuestaSim) — run from any directory:
//   export SOC_UVM=$HOME/SOC_UVM
//   vlog -64 -f $SOC_UVM/verif/sim/compile_uvm_tb.f
//
// All paths use $SOC_UVM environment variable for portability.
//
// Note: Cheshire RTL must be compiled FIRST via Bender-generated scripts
//       into $SOC_UVM/cheshire/target/sim/vsim/work.
//       This file compiles TB into the same library via -work.
// ============================================================================

// ─── Target Work Library (same as RTL) ───
-work $SOC_UVM/cheshire/target/sim/vsim/work

// ─── Compiler Options ───
-sv
-timescale 1ns/1ps
-suppress 2583
-suppress 13314

// ─── Include Directories ───
+incdir+$SOC_UVM/verif/tb/agents/jtag_agent
+incdir+$SOC_UVM/verif/tb/agents/uart_agent
+incdir+$SOC_UVM/verif/tb/agents/spi_agent
+incdir+$SOC_UVM/verif/tb/agents/i2c_agent
+incdir+$SOC_UVM/verif/tb/agents/gpio_agent
+incdir+$SOC_UVM/verif/tb/agents/axi_agent
+incdir+$SOC_UVM/verif/tb/agents/slink_agent
+incdir+$SOC_UVM/verif/tb/agents/vga_agent
+incdir+$SOC_UVM/verif/tb/agents/usb_agent
+incdir+$SOC_UVM/verif/tb/env
+incdir+$SOC_UVM/verif/tb/sequences
+incdir+$SOC_UVM/verif/tb/sequences/ip
+incdir+$SOC_UVM/verif/tb/sequences/virtual
+incdir+$SOC_UVM/verif/tb/tests

// ─── Cheshire RTL Include Directories (for tb_top.sv typedefs) ───
+incdir+$SOC_UVM/cheshire/hw/include
+incdir+$SOC_UVM/cheshire/.bender/git/checkouts/axi-ecdc900686449c15/include
+incdir+$SOC_UVM/cheshire/.bender/git/checkouts/register_interface-902ad5bfde7bb98c/include
+incdir+$SOC_UVM/cheshire/.bender/git/checkouts/common_cells-7f7ae0f5e6bf7fb5/include

// ─── Interface Files (compile before packages) ───
$SOC_UVM/verif/tb/agents/jtag_agent/jtag_if.sv
$SOC_UVM/verif/tb/agents/uart_agent/uart_if.sv
$SOC_UVM/verif/tb/agents/spi_agent/spi_if.sv
$SOC_UVM/verif/tb/agents/i2c_agent/i2c_if.sv
$SOC_UVM/verif/tb/agents/gpio_agent/gpio_if.sv
$SOC_UVM/verif/tb/agents/axi_agent/chs_axi_if.sv

// ─── New Agent Interface Files (Aşama 10: Out-of-Scope IPs) ───
$SOC_UVM/verif/tb/agents/slink_agent/slink_if.sv
$SOC_UVM/verif/tb/agents/vga_agent/vga_if.sv
$SOC_UVM/verif/tb/agents/usb_agent/usb_if.sv

// ─── UVM Agent Packages ───
$SOC_UVM/verif/tb/agents/jtag_agent/jtag_pkg.sv
$SOC_UVM/verif/tb/agents/uart_agent/uart_pkg.sv
$SOC_UVM/verif/tb/agents/spi_agent/spi_pkg.sv
$SOC_UVM/verif/tb/agents/i2c_agent/i2c_pkg.sv
$SOC_UVM/verif/tb/agents/gpio_agent/gpio_pkg.sv
$SOC_UVM/verif/tb/agents/axi_agent/chs_axi_pkg.sv

// ─── New Agent Packages (Aşama 10: Out-of-Scope IPs) ───
$SOC_UVM/verif/tb/agents/slink_agent/slink_pkg.sv
$SOC_UVM/verif/tb/agents/vga_agent/vga_pkg.sv
$SOC_UVM/verif/tb/agents/usb_agent/usb_pkg.sv

// ─── RAL Package ───
+incdir+$SOC_UVM/verif/tb/env/ral
$SOC_UVM/verif/tb/env/ral/chs_ral_pkg.sv

// ─── Environment Package ───
$SOC_UVM/verif/tb/env/chs_env_pkg.sv

// ─── Sequence Package ───
$SOC_UVM/verif/tb/sequences/chs_seq_pkg.sv

// ─── Test Package ───
$SOC_UVM/verif/tb/tests/chs_test_pkg.sv

// ─── SVA Protocol Checker ───
$SOC_UVM/verif/tb/top/chs_protocol_checker.sv

// ─── AXI SVA Protocol Checker (Aşama 8) ───
$SOC_UVM/verif/tb/top/chs_axi_protocol_checker.sv

// ─── SoC-Level SVA Checker (Aşama 7) ───
$SOC_UVM/verif/tb/top/chs_soc_sva_checker.sv

// ─── Testbench Top ───
$SOC_UVM/verif/tb/top/tb_top.sv

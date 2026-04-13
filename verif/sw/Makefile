# ==============================================================================
# Makefile — Cheshire SoC Bare-Metal Test Build System
#
# Usage:
#   make all          Build all tests
#   make test_hello   Build specific test
#   make clean        Remove build artifacts
#   make dump         Show disassembly of all tests
#
# Requirements:
#   - RISC-V GCC toolchain (riscv64-unknown-elf-gcc)
#   - Set RISCV_PREFIX if not in PATH
# ==============================================================================

# ─── Toolchain ───
RISCV_PREFIX ?= riscv64-unknown-elf-
CC      = $(RISCV_PREFIX)gcc
OBJDUMP = $(RISCV_PREFIX)objdump
OBJCOPY = $(RISCV_PREFIX)objcopy
SIZE    = $(RISCV_PREFIX)size

# ─── Directories ───
SW_DIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
INC_DIR   := $(SW_DIR)include
LINK_DIR  := $(SW_DIR)link
TEST_DIR  := $(SW_DIR)tests
BUILD_DIR := $(SW_DIR)build

# ─── Source files ───
CRT0      := $(SW_DIR)crt0.S
LINKER    := $(LINK_DIR)/spm.ld
TESTS_C   := $(wildcard $(TEST_DIR)/*.c)
TESTS     := $(notdir $(basename $(TESTS_C)))

# ─── Compiler Flags ───
CFLAGS  = -march=rv64gc -mabi=lp64d
CFLAGS += -mcmodel=medany -mexplicit-relocs
CFLAGS += -O2 -Wall -Wextra
CFLAGS += -ffunction-sections -fdata-sections
CFLAGS += -fno-builtin -static
CFLAGS += -I$(INC_DIR)

# ─── Linker Flags ───
LDFLAGS  = -nostartfiles
LDFLAGS += -T $(LINKER)
LDFLAGS += -Wl,--gc-sections
LDFLAGS += -static

# ─── Targets ───
ELFS  := $(addprefix $(BUILD_DIR)/, $(addsuffix .elf, $(TESTS)))
DUMPS := $(addprefix $(BUILD_DIR)/, $(addsuffix .dump, $(TESTS)))
BINS  := $(addprefix $(BUILD_DIR)/, $(addsuffix .bin, $(TESTS)))
MEMHS := $(addprefix $(BUILD_DIR)/, $(addsuffix .memh, $(TESTS)))
WORDS := $(addprefix $(BUILD_DIR)/, $(addsuffix .words, $(TESTS)))

# ═══════════════════════════════════════════════
# Default target
# ═══════════════════════════════════════════════
.PHONY: all clean dump sizes help

all: $(ELFS) $(DUMPS) $(MEMHS) $(WORDS)
	@echo ""
	@echo "═══════════════════════════════════════"
	@echo "  Build Complete: $(words $(ELFS)) tests"
	@echo "═══════════════════════════════════════"
	@for f in $(ELFS); do \
		echo "  ✓ $$(basename $$f)"; \
	done
	@echo ""

# ─── Build directory ───
$(BUILD_DIR):
	@mkdir -p $@

# ─── Compile and link each test ───
$(BUILD_DIR)/%.elf: $(TEST_DIR)/%.c $(CRT0) $(LINKER) | $(BUILD_DIR)
	@echo "[CC+LD] $< → $@"
	$(CC) $(CFLAGS) $(LDFLAGS) $(CRT0) $< -o $@

# ─── Generate disassembly ───
$(BUILD_DIR)/%.dump: $(BUILD_DIR)/%.elf
	@echo "[DUMP]  $< → $@"
	$(OBJDUMP) -d -S -t $< > $@

# ─── Generate binary ───
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf
	@echo "[BIN]   $< → $@"
	$(OBJCOPY) -O binary $< $@

# ─── Generate plain 32-bit word list (for UVM SW-driven loader) ───
$(BUILD_DIR)/%.words: $(BUILD_DIR)/%.bin
	@echo "[WORDS] $< → $@"
	od -An -tx4 -w4 -v $< | tr -s ' ' '\n' | sed '/^$$/d' > $@

# ─── Generate Verilog hex (for $readmemh) ───
$(BUILD_DIR)/%.memh: $(BUILD_DIR)/%.elf
	@echo "[MEMH]  $< → $@"
	$(OBJCOPY) -O verilog $< $@

# ─── Individual test targets ───
$(foreach t,$(TESTS),$(eval $(t): $(BUILD_DIR)/$(t).elf $(BUILD_DIR)/$(t).dump $(BUILD_DIR)/$(t).memh))

# ─── Show all disassemblies ───
dump: $(DUMPS)
	@for f in $(DUMPS); do \
		echo ""; \
		echo "═══════════ $$(basename $$f) ═══════════"; \
		cat $$f; \
	done

# ─── Show sizes ───
sizes: $(ELFS)
	@echo ""
	@echo "═══════════ Test Binary Sizes ═══════════"
	$(SIZE) $(ELFS)
	@echo ""

# ─── Clean ───
clean:
	rm -rf $(BUILD_DIR)

# ─── Help ───
help:
	@echo "Cheshire SoC Bare-Metal Test Build System"
	@echo ""
	@echo "Available tests:"
	@for t in $(TESTS); do echo "  make $$t"; done
	@echo ""
	@echo "Commands:"
	@echo "  make all     Build all tests"
	@echo "  make clean   Remove build artifacts"
	@echo "  make sizes   Show binary sizes"
	@echo "  make dump    Show disassemblies"
	@echo "  make test_x  Build .elf/.dump/.memh for one test"
	@echo "  make all     Also generates .words files for UVM SW loader"
	@echo "  make help    This message"

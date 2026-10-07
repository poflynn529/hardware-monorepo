.PHONY: all compile lint test test-one clean

VERILATOR ?= verilator
TOP       ?= fifo
SRC       ?= fifo.sv
OBJ_DIR   = obj_dir
WIDTH     ?= 64
DEPTH     ?= 8
SEED      ?= 305419896
JOBS      ?= 2
TEST_DIR  = $(OBJ_DIR)/tb_w$(WIDTH)_d$(DEPTH)
FST       ?= $(TEST_DIR)/fifo_seed$(SEED).fst

all: compile

compile: $(SRC)
	$(VERILATOR) --cc --sv -Wall --top-module $(TOP) $<

lint: $(SRC)
	$(VERILATOR) --lint-only --sv -Wall --top-module $(TOP) $<

test-one:
	mkdir -p $(TEST_DIR)
	$(VERILATOR) --binary --timing --trace-fst --sv -Wall -Wno-fatal -j $(JOBS) \
		--top-module fifo_tb --Mdir $(TEST_DIR) \
		-GDATA_WIDTH=$(WIDTH) -GDEPTH=$(DEPTH) $(SRC) fifo_tb.sv
	$(TEST_DIR)/Vfifo_tb +seed=$(SEED) +fst=$(FST)

test:
	@status=0; for config in '1 2' '8 3' '17 8' '64 17' '64 512'; do \
		set -- $$config; \
		$(MAKE) --no-print-directory test-one WIDTH=$$1 DEPTH=$$2 SEED=$(SEED) || status=1; \
	done; exit $$status

clean:
	$(RM) -r $(OBJ_DIR)

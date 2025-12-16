.PHONY: all help jobs submit status collect analyze venv clean distclean

# Include configuration
include config.mk

# Computed variables
TOTAL_RUNS := $(shell echo "$(words $(COMPILERS)) * $(RUNS_PER_COMPILER)" | bc)

all: help

help:
	@echo "========================================"
	@echo "Stdlib Compilation Time Benchmark"
	@echo "========================================"
	@echo ""
	@echo "Workflow:"
	@echo "  1. make jobs       - Generate SLURM job scripts"
	@echo "  2. make submit     - Submit all jobs to cluster"
	@echo "  3. make status     - Check job status"
	@echo "  4. make collect    - Collect results (run after jobs complete)"
	@echo "  5. make analyze    - Statistical analysis with t-test"
	@echo ""
	@echo "Configuration:"
	@echo "  Compilers: $(COMPILERS)"
	@echo "  Runs per compiler: $(RUNS_PER_COMPILER)"
	@echo "  Total jobs: $(TOTAL_RUNS)"
	@echo "  Build targets: $(BUILD_TARGETS)"
	@echo "  Build system: $(BUILD_SYSTEM)"
	@echo "  SLURM partition: $(SLURM_PARTITION)"
	@echo "  SLURM account: $(SLURM_ACCOUNT)"
	@echo ""
	@echo "Other targets:"
	@echo "  make venv      - Setup Python virtual environment (for analysis)"
	@echo "  make clean     - Remove results and generated files"
	@echo "  make distclean - Remove everything including venv"
	@echo ""
	@echo "Edit config.mk to change configuration."

jobs:
	@echo "Generating SLURM job scripts..."
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER=$(RUNS_PER_COMPILER) \
	 SAC2C_NEW_SLURM="$(SAC2C_NEW_SLURM)" \
	 SAC2C_ORIG_SLURM="$(SAC2C_ORIG_SLURM)" \
	 SAC2C_NEW_DIR_SLURM="$(SAC2C_NEW_DIR_SLURM)" \
	 SAC2C_ORIG_DIR_SLURM="$(SAC2C_ORIG_DIR_SLURM)" \
	 STDLIB_SRC_SLURM="$(STDLIB_SRC_SLURM)" \
	 BUILD_TARGETS="$(BUILD_TARGETS)" \
	 BUILD_SYSTEM="$(BUILD_SYSTEM)" \
	 SLURM_TIMELIMIT="$(SLURM_TIMELIMIT)" \
	 SLURM_CPUS=$(SLURM_CPUS) \
	 SLURM_MEM="$(SLURM_MEM)" \
	 SLURM_ACCOUNT="$(SLURM_ACCOUNT)" \
	 SLURM_PARTITION="$(SLURM_PARTITION)" \
	 ./scripts/generate_jobs.sh

submit: jobs
	@echo "Submitting $(TOTAL_RUNS) jobs to SLURM..."
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER=$(RUNS_PER_COMPILER) \
	 ./scripts/submit_all.sh

status:
	@echo "Checking SLURM job status..."
	@./scripts/check_jobs.sh

collect:
	@echo "Collecting results from $(TOTAL_RUNS) jobs..."
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER=$(RUNS_PER_COMPILER) \
	 ./scripts/collect_results.sh

analyze: venv
	@if [ ! -f summary/combined_results.csv ]; then \
		echo "ERROR: No results found. Run 'make collect' first."; \
		exit 1; \
	fi
	@echo "Performing statistical analysis..."
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER=$(RUNS_PER_COMPILER) \
	 BUILD_TARGETS="$(BUILD_TARGETS)" \
	 BUILD_SYSTEM="$(BUILD_SYSTEM)" \
	 SLURM_PARTITION="$(SLURM_PARTITION)" \
	 PYTHON="$(PYTHON)" \
	 ./scripts/analyze.sh
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER=$(RUNS_PER_COMPILER) \
	 BUILD_TARGETS="$(BUILD_TARGETS)" \
	 BUILD_SYSTEM="$(BUILD_SYSTEM)" \
	 PYTHON="$(PYTHON)" \
	 ./scripts/analyze_json.sh
	@echo ""
	@echo "Analysis complete!"
	@echo "  - Markdown summary: summary/analysis.md"
	@echo "  - JSON output: summary/analysis.json"

venv:
	@if [ ! -f $(VENV_DIR)/bin/activate ]; then \
		echo "Creating Python virtual environment..."; \
		python3 -m venv $(VENV_DIR); \
		$(VENV_DIR)/bin/pip install --upgrade pip; \
		$(VENV_DIR)/bin/pip install scipy numpy; \
		echo "Virtual environment created successfully."; \
	else \
		echo "Virtual environment already exists."; \
	fi

clean:
	@echo "Cleaning generated files..."
	@rm -rf jobs/ results/ summary/
	@rm -f job_ids.txt slurm-*.out slurm-*.err
	@echo "Cleanup complete."

distclean: clean
	@echo "Removing virtual environment..."
	@rm -rf $(VENV_DIR)
	@echo "Full cleanup complete."

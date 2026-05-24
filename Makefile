.PHONY: all run jobs submit wait status collect retry report venv clean distclean print-config help

include config.mk

# Default target: one-shot end-to-end.
all: run

# ---------------------------------------------------------------------------
# One-command end-to-end run (this is the only command you normally need).
# ---------------------------------------------------------------------------
run: venv
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER="$(RUNS_PER_COMPILER)" \
	 BUILD_TARGETS="$(BUILD_TARGETS)" \
	 BUILD_SYSTEM="$(BUILD_SYSTEM)" \
	 SLURM_PARTITION="$(SLURM_PARTITION)" \
	 SLURM_ACCOUNT="$(SLURM_ACCOUNT)" \
	 SLURM_CPUS="$(SLURM_CPUS)" \
	 SLURM_MEM="$(SLURM_MEM)" \
	 SLURM_TIMELIMIT="$(SLURM_TIMELIMIT)" \
	 SLURM_ARRAY_CONCURRENCY="$(SLURM_ARRAY_CONCURRENCY)" \
	 SAC2C_NEW_SLURM="$(SAC2C_NEW_SLURM)" \
	 SAC2C_ORIG_SLURM="$(SAC2C_ORIG_SLURM)" \
	 SAC2C_NEW_DIR_SLURM="$(SAC2C_NEW_DIR_SLURM)" \
	 SAC2C_ORIG_DIR_SLURM="$(SAC2C_ORIG_DIR_SLURM)" \
	 SAC2C_NEW_SRC_SLURM="$(SAC2C_NEW_SRC_SLURM)" \
	 SAC2C_ORIG_SRC_SLURM="$(SAC2C_ORIG_SRC_SLURM)" \
	 STDLIB_SRC_SLURM="$(STDLIB_SRC_SLURM)" \
	 TEMP_ROOT_PREFERRED="$(TEMP_ROOT_PREFERRED)" \
	 TEMP_ROOT_FALLBACK="$(TEMP_ROOT_FALLBACK)" \
	 MAX_RETRIES="$(MAX_RETRIES)" \
	 PYTHON="$(PYTHON)" \
	 ./scripts/run_all.sh

# ---------------------------------------------------------------------------
# Granular targets (for debugging / partial reruns).
# ---------------------------------------------------------------------------
jobs:
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER="$(RUNS_PER_COMPILER)" \
	 BUILD_TARGETS="$(BUILD_TARGETS)" \
	 BUILD_SYSTEM="$(BUILD_SYSTEM)" \
	 SLURM_TIMELIMIT="$(SLURM_TIMELIMIT)" \
	 SLURM_CPUS="$(SLURM_CPUS)" \
	 SLURM_MEM="$(SLURM_MEM)" \
	 SLURM_ACCOUNT="$(SLURM_ACCOUNT)" \
	 SLURM_PARTITION="$(SLURM_PARTITION)" \
	 SLURM_ARRAY_CONCURRENCY="$(SLURM_ARRAY_CONCURRENCY)" \
	 SAC2C_NEW_SLURM="$(SAC2C_NEW_SLURM)" \
	 SAC2C_ORIG_SLURM="$(SAC2C_ORIG_SLURM)" \
	 SAC2C_NEW_DIR_SLURM="$(SAC2C_NEW_DIR_SLURM)" \
	 SAC2C_ORIG_DIR_SLURM="$(SAC2C_ORIG_DIR_SLURM)" \
	 SAC2C_NEW_SRC_SLURM="$(SAC2C_NEW_SRC_SLURM)" \
	 SAC2C_ORIG_SRC_SLURM="$(SAC2C_ORIG_SRC_SLURM)" \
	 STDLIB_SRC_SLURM="$(STDLIB_SRC_SLURM)" \
	 TEMP_ROOT_PREFERRED="$(TEMP_ROOT_PREFERRED)" \
	 TEMP_ROOT_FALLBACK="$(TEMP_ROOT_FALLBACK)" \
	 ./scripts/generate_jobs.sh

submit:
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER="$(RUNS_PER_COMPILER)" \
	 ./scripts/submit_all.sh

wait:
	@./scripts/wait_jobs.sh

status:
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER="$(RUNS_PER_COMPILER)" \
	 ./scripts/check_jobs.sh

retry:
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER="$(RUNS_PER_COMPILER)" \
	 PYTHON="$(PYTHON)" \
	 SLURM_ARRAY_CONCURRENCY="$(SLURM_ARRAY_CONCURRENCY)" \
	 ./scripts/retry_failed.sh

collect:
	@COMPILERS="$(COMPILERS)" \
	 RUNS_PER_COMPILER="$(RUNS_PER_COMPILER)" \
	 BUILD_TARGETS="$(BUILD_TARGETS)" \
	 BUILD_SYSTEM="$(BUILD_SYSTEM)" \
	 SLURM_PARTITION="$(SLURM_PARTITION)" \
	 SLURM_ACCOUNT="$(SLURM_ACCOUNT)" \
	 SLURM_CPUS="$(SLURM_CPUS)" \
	 SLURM_MEM="$(SLURM_MEM)" \
	 SLURM_TIMELIMIT="$(SLURM_TIMELIMIT)" \
	 PYTHON="$(PYTHON)" \
	 ./scripts/collect_results.sh

report: venv
	@if [ ! -f summary/combined_results.csv ]; then \
		echo "ERROR: summary/combined_results.csv missing — run 'make collect' first."; \
		exit 1; \
	fi
	@PYTHON="$(PYTHON)" ./scripts/generate_report.sh

# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
venv:
	@if [ ! -f $(VENV_DIR)/bin/activate ]; then \
		echo "Creating Python virtual environment..."; \
		python3 -m venv $(VENV_DIR); \
		$(VENV_DIR)/bin/pip install --upgrade pip >/dev/null; \
		$(VENV_DIR)/bin/pip install scipy numpy >/dev/null; \
	fi

print-config:
	@echo "Compilers          : $(COMPILERS)"
	@echo "Runs per compiler  : $(RUNS_PER_COMPILER)"
	@echo "Build targets      : $(BUILD_TARGETS)"
	@echo "Build system       : $(BUILD_SYSTEM)"
	@echo "Max retries        : $(MAX_RETRIES)"
	@echo "SAC2C new          : $(SAC2C_NEW_SLURM) (src: $(SAC2C_NEW_SRC_SLURM))"
	@echo "SAC2C orig         : $(SAC2C_ORIG_SLURM) (src: $(SAC2C_ORIG_SRC_SLURM))"
	@echo "Stdlib             : $(STDLIB_SRC_SLURM)"
	@echo "SLURM partition    : $(SLURM_PARTITION)"
	@echo "SLURM cpus/mem/time: $(SLURM_CPUS) / $(SLURM_MEM) / $(SLURM_TIMELIMIT)"
	@echo "Array concurrency  : $(SLURM_ARRAY_CONCURRENCY)"
	@echo "Temp root          : $(TEMP_ROOT_PREFERRED) (fallback: $(TEMP_ROOT_FALLBACK))"

# Move the previous run's artefacts into archive/<timestamp>/ rather than
# deleting them outright. Safer than `rm -rf`.
clean:
	@stamp=$$(date +%Y%m%dT%H%M%S); \
	 if [ -d results ] || [ -d summary ] || [ -d jobs ] || \
	    ls slurm-*.out >/dev/null 2>&1 || [ -f job_ids.txt ]; then \
		mkdir -p archive/$$stamp; \
		[ -d jobs ]    && mv jobs    archive/$$stamp/ 2>/dev/null || true; \
		[ -d results ] && mv results archive/$$stamp/ 2>/dev/null || true; \
		[ -d summary ] && mv summary archive/$$stamp/ 2>/dev/null || true; \
		mv slurm-*.out slurm-*.err archive/$$stamp/ 2>/dev/null || true; \
		mv job_ids.txt archive/$$stamp/ 2>/dev/null || true; \
		echo "Previous run archived to archive/$$stamp/"; \
	 else \
		echo "Nothing to clean."; \
	 fi

distclean: clean
	@rm -rf $(VENV_DIR)
	@echo "Removed venv."

help:
	@echo "Usage:"
	@echo "  make run      end-to-end: jobs -> submit -> wait -> retry -> collect -> report"
	@echo "  make status   per-task status of the current submission"
	@echo "  make report   regenerate summary/report.md from existing results/"
	@echo "  make clean    archive jobs/results/summary into archive/<timestamp>/"
	@echo
	@echo "  Granular debugging targets: jobs, submit, wait, retry, collect, print-config"
	@echo
	@echo "Edit config.mk to change compilers, run count, SLURM caps, etc."

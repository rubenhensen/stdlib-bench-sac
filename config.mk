# Stdlib Compilation Time Benchmark — configuration
# Edit and then run `make` (= `make run`) for an end-to-end rerun.

# =============================================================================
# Compiler paths (on the SLURM compute nodes)
# =============================================================================
SAC2C_NEW_SLURM       := /home/rhensen/sac2c/build_p/sac2c_p
SAC2C_ORIG_SLURM      := /home/rhensen/sacoriginal/sac2c/build_p/sac2c_p
SAC2C_NEW_DIR_SLURM   := /home/rhensen/sac2c/build_p
SAC2C_ORIG_DIR_SLURM  := /home/rhensen/sacoriginal/sac2c/build_p

# Source-tree paths for the compiler repos (used to extract commit hashes).
# Leave empty if no .git is present; the run still works.
SAC2C_NEW_SRC_SLURM   := /home/rhensen/sac2c
SAC2C_ORIG_SRC_SLURM  := /home/rhensen/sacoriginal/sac2c

# =============================================================================
# Stdlib source path
# =============================================================================
STDLIB_SRC_SLURM := /home/rhensen/Stdlib

# =============================================================================
# Build configuration
# =============================================================================
COMPILERS          := new orig
RUNS_PER_COMPILER  := 32
BUILD_TARGETS      := seq;mt_pth
BUILD_SYSTEM       := make

# Retry rounds for runs that did not finish SUCCESSfully (0 disables retry)
MAX_RETRIES        := 2

# =============================================================================
# SLURM configuration
# =============================================================================
SLURM_ACCOUNT      := csmpi
SLURM_PARTITION    := csmpi_fpga_long
SLURM_CPUS         := 4
SLURM_MEM          := 14G
SLURM_TIMELIMIT    := 02:00:00

# Optional: cap simultaneous array tasks per compiler. Empty = no cap.
# (Radboud SLURM docs: `--array 1-N%K` runs at most K tasks concurrently.)
SLURM_ARRAY_CONCURRENCY :=

# Where each task should put its temporary build tree. The Radboud cluster docs
# state that local /scratch is much, much faster than the home filesystem.
# We use /scratch/$USER if it exists at run time, otherwise fall back to $HOME.
# (The fallback logic lives in job_template.sh.)
TEMP_ROOT_PREFERRED := /scratch
TEMP_ROOT_FALLBACK  := $$HOME

# =============================================================================
# Analysis configuration
# =============================================================================
VENV_DIR := venv
PYTHON   := $(VENV_DIR)/bin/python3

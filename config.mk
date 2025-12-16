# Stdlib Compilation Time Benchmark - Configuration
# Edit this file to match your environment

# =============================================================================
# Compiler Paths
# =============================================================================

# Local paths (for login node)
SAC2C_NEW_LOCAL := /home/ruben/Repos/sac2c/build_p/sac2c_p
SAC2C_ORIG_LOCAL := /home/ruben/Repos/sacoriginal/sac2c/build_p/sac2c_p

# SLURM paths (for compute nodes - username may differ)
SAC2C_NEW_SLURM := /home/rhensen/sac2c/build_p/sac2c_p
SAC2C_ORIG_SLURM := /home/rhensen/sacoriginal/sac2c/build_p/sac2c_p

# =============================================================================
# Stdlib Source Paths
# =============================================================================

# Local path
STDLIB_SRC_LOCAL := /home/ruben/Repos/Stdlib

# SLURM path (compute nodes)
STDLIB_SRC_SLURM := /home/rhensen/Stdlib

# =============================================================================
# Build Configuration
# =============================================================================

# Compiler identifiers (used in filenames and job names)
COMPILERS := new orig

# Number of runs per compiler for statistical confidence
# Recommended: 8-10 runs for ~15% difference detection at 95% confidence
RUNS_PER_COMPILER := 10

# CMake build targets (semicolon-separated)
# Common options: seq, seq_checks, mt_pth, cuda_man
BUILD_TARGETS := seq;mt_pth

# Build system (make or ninja)
BUILD_SYSTEM := make

# =============================================================================
# SLURM Configuration
# =============================================================================

# SLURM account and partition
SLURM_ACCOUNT := csmpi
SLURM_PARTITION := csmpi_fpga_long

# Resource allocation per job
SLURM_CPUS := 16
SLURM_MEM := 32G
SLURM_TIMELIMIT := 02:00:00

# GPU allocation (set to empty string if not needed)
SLURM_GPU :=

# =============================================================================
# Analysis Configuration
# =============================================================================

# Python virtual environment path
VENV_DIR := venv

# Python executable (will be created by 'make venv')
PYTHON := $(VENV_DIR)/bin/python3

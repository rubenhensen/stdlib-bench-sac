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
# Discovered via `sinfo` + `sacctmgr show assoc user=$USER` on cn00:
#   * Account csmpi works (icis also exists but csmpi is the research group).
#   * Only two public partitions: cncz (24 h cap) and cnczshort (12 h cap).
#   * DefMemPerCPU on cncz is only 2 GB, so --mem must be set explicitly.
#   * cncz currently has 3 nodes (cn00 idle, cn58 plnd, cn99 mix).
SLURM_ACCOUNT      := csmpi
SLURM_PARTITION    := cncz
SLURM_CPUS         := 4
SLURM_MEM          := 14G
SLURM_TIMELIMIT    := 02:00:00

# Optional: cap simultaneous array tasks per compiler. Empty = no cap.
# (Radboud SLURM docs: `--array 1-N%K` runs at most K tasks concurrently.)
# With only 3 nodes in cncz, cap at 4 to leave room for other cluster users.
SLURM_ARRAY_CONCURRENCY := 4

# Restrict which compute nodes the benchmark runs on. CRUCIAL for benchmark
# validity: cncz nodes differ in CPU generation and load, and mixing them
# produces 2× differences in compile time that swamp the signal.
#
# Use EXACTLY ONE of:
#   SLURM_NODELIST    := cn99            # pin to ONE specific node — best for validity
#   SLURM_EXCLUDE     := cn58            # exclude known-slow nodes — keeps parallelism
# Leave both empty to let SLURM decide (NOT recommended for benchmark runs).
#
# DEFAULT: pin to cn99. Empirically (see thesis evaluation), cn58 is ~2× slower
# than cn00/cn99 on the same workload — mixing produces noise that swamps the
# signal. Pinning to one node is the only honest way to compare compile times.
#
# Discover node specs with:
#   sinfo -N -o "%N %c %m %f"
#   scontrol show node cn58 | grep -E 'CPU|Memory|Active'
SLURM_NODELIST     := cn99
SLURM_EXCLUDE      :=

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

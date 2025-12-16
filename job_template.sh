#!/bin/bash
#SBATCH --job-name=stdlib-COMPILER-RUN
#SBATCH --output=slurm-COMPILER-RUN-%j.out
#SBATCH --error=slurm-COMPILER-RUN-%j.err
#SBATCH --time=__TIMELIMIT__
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=__CPUS__
#SBATCH --mem=__MEM__
#SBATCH --account=__ACCOUNT__
#SBATCH --partition=__PARTITION__

# =============================================================================
# Stdlib Compilation Time Benchmark - SLURM Job
# =============================================================================

# Build configuration (filled by generate_jobs.sh)
COMPILER="__COMPILER__"
RUN_NUM="__RUN__"
SAC2C_PATH="__SAC2C_PATH__"
STDLIB_SRC="__STDLIB_SRC__"
BUILD_TARGETS="__BUILD_TARGETS__"
BUILD_SYSTEM="__BUILD_SYSTEM__"

# Create unique temporary build directory in home
TEMP_BUILD_DIR="${HOME}/tmp_stdlib_build_${COMPILER}_${RUN_NUM}_${SLURM_JOB_ID}"

echo "========================================"
echo "Stdlib Compilation Benchmark"
echo "========================================"
echo "Compiler: $COMPILER"
echo "Run: $RUN_NUM"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "Temp Build Dir: $TEMP_BUILD_DIR"
echo "SAC2C: $SAC2C_PATH"
echo "Stdlib Source: $STDLIB_SRC"
echo "Build Targets: $BUILD_TARGETS"
echo "Build System: $BUILD_SYSTEM"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "========================================"
echo ""

# Initialize result CSV for this job
SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$(pwd)}"
RESULT_FILE="${SUBMIT_DIR}/results/stdlib-${COMPILER}-${RUN_NUM}.csv"
mkdir -p "${SUBMIT_DIR}/results"
echo "compiler,run,compilation_time_seconds,job_id,node,timestamp" > "$RESULT_FILE"

# Verify SAC2C is accessible
if [ ! -x "$SAC2C_PATH" ]; then
    echo "ERROR: SAC2C compiler not found or not executable: $SAC2C_PATH"
    echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
    exit 1
fi

# Verify source directory exists
if [ ! -d "$STDLIB_SRC" ]; then
    echo "ERROR: Stdlib source directory not found: $STDLIB_SRC"
    echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
    exit 1
fi

echo "Verifying compiler:"
"$SAC2C_PATH" -V 2>&1 | head -3
echo ""

echo "Creating temporary build directory..."
mkdir -p "$TEMP_BUILD_DIR" || {
    echo "ERROR: Failed to create temporary build directory"
    echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
    exit 1
}

echo "Starting clean build..."
echo ""

# =============================================================================
# TIMED BUILD PROCESS
# =============================================================================

# Start high-precision timing
START_TIME=$(date +%s.%N)

# Change to temp directory
cd "$TEMP_BUILD_DIR" || {
    echo "ERROR: Failed to change to temp directory"
    echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
    exit 1
}

# Create build directory
mkdir -p build || {
    echo "ERROR: Failed to create build directory"
    echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
    exit 1
}

cd build || {
    echo "ERROR: Failed to change to build directory"
    echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
    exit 1
}

# CMake configuration
echo "Running CMake configuration..."
if [ "$BUILD_SYSTEM" = "ninja" ]; then
    cmake -DTARGETS="$BUILD_TARGETS" \
          -DSAC2C_EXEC="$SAC2C_PATH" \
          -GNinja \
          "$STDLIB_SRC" || {
        echo "ERROR: CMake configuration failed"
        echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
        cd /
        rm -rf "$TEMP_BUILD_DIR"
        exit 1
    }

    echo ""
    echo "Running Ninja build..."
    ninja || {
        echo "ERROR: Ninja build failed"
        echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
        cd /
        rm -rf "$TEMP_BUILD_DIR"
        exit 1
    }
else
    cmake -DTARGETS="$BUILD_TARGETS" \
          -DSAC2C_EXEC="$SAC2C_PATH" \
          "$STDLIB_SRC" || {
        echo "ERROR: CMake configuration failed"
        echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
        cd /
        rm -rf "$TEMP_BUILD_DIR"
        exit 1
    }

    echo ""
    echo "Running Make build..."
    make -j "$SLURM_CPUS_PER_TASK" || {
        echo "ERROR: Make build failed"
        echo "${COMPILER},${RUN_NUM},ERROR,-1,$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"
        cd /
        rm -rf "$TEMP_BUILD_DIR"
        exit 1
    }
fi

# End timing
END_TIME=$(date +%s.%N)

# =============================================================================
# CALCULATE AND RECORD RESULTS
# =============================================================================

# Calculate compilation time
COMPILATION_TIME=$(echo "$END_TIME - $START_TIME" | bc)

echo ""
echo "========================================"
echo "Build completed successfully!"
echo "Compilation time: $COMPILATION_TIME seconds"
echo "========================================"

# Record result
echo "${COMPILER},${RUN_NUM},${COMPILATION_TIME},${SLURM_JOB_ID},$(hostname),$(date -Iseconds)" >> "$RESULT_FILE"

# =============================================================================
# CLEANUP
# =============================================================================

echo ""
echo "Cleaning up temporary build directory..."
cd /
rm -rf "$TEMP_BUILD_DIR"

echo "Job complete. Results saved to $RESULT_FILE"

#!/bin/bash

# =============================================================================
# Generate SLURM Job Scripts from Template
# =============================================================================

# Change to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

# Configuration comes from environment variables (set by Makefile)
echo "Generating SLURM job scripts..."
echo "==============================="
echo ""

# Create jobs directory
mkdir -p jobs

# Counter for total jobs
job_count=0

# Generate jobs for each compiler
for compiler in $COMPILERS; do
    # Set compiler-specific variables
    case $compiler in
        new)
            SAC2C_PATH="$SAC2C_NEW_SLURM"
            SAC2C_DIR="$SAC2C_NEW_DIR_SLURM"
            ;;
        orig)
            SAC2C_PATH="$SAC2C_ORIG_SLURM"
            SAC2C_DIR="$SAC2C_ORIG_DIR_SLURM"
            ;;
        *)
            echo "ERROR: Unknown compiler: $compiler"
            exit 1
            ;;
    esac

    echo "Generating jobs for compiler: $compiler"
    echo "  SAC2C path: $SAC2C_PATH"

    # Generate jobs for each run
    for run in $(seq 1 "$RUNS_PER_COMPILER"); do
        job_file="jobs/stdlib-${compiler}-${run}.sh"

        # Create job script from template with substitutions
        sed -e "s|__COMPILER__|${compiler}|g" \
            -e "s|__RUN__|${run}|g" \
            -e "s|__SAC2C_PATH__|${SAC2C_PATH}|g" \
            -e "s|__SAC2C_DIR__|${SAC2C_DIR}|g" \
            -e "s|__STDLIB_SRC__|${STDLIB_SRC_SLURM}|g" \
            -e "s|__BUILD_TARGETS__|${BUILD_TARGETS}|g" \
            -e "s|__BUILD_SYSTEM__|${BUILD_SYSTEM}|g" \
            -e "s|__TIMELIMIT__|${SLURM_TIMELIMIT}|g" \
            -e "s|__CPUS__|${SLURM_CPUS}|g" \
            -e "s|__MEM__|${SLURM_MEM}|g" \
            -e "s|__ACCOUNT__|${SLURM_ACCOUNT}|g" \
            -e "s|__PARTITION__|${SLURM_PARTITION}|g" \
            -e "s|COMPILER-RUN|${compiler}-${run}|g" \
            job_template.sh > "$job_file"

        chmod +x "$job_file"
        job_count=$((job_count + 1))
        echo "  Generated: $job_file"
    done
    echo ""
done

echo "==============================="
echo "Generated $job_count job scripts in jobs/ directory"
echo "Ready to submit with: make submit"

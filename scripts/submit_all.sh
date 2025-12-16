#!/bin/bash

# =============================================================================
# Submit All SLURM Jobs
# =============================================================================

# Change to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

# Configuration comes from environment variables (set by Makefile)

echo "Submitting Stdlib Compilation Benchmark Jobs"
echo "============================================="
echo ""

# Create arrays to store job information
declare -a job_ids
declare -a job_names

# Create results directory
mkdir -p results

# Submit each job
for compiler in $COMPILERS; do
    for run in $(seq 1 "$RUNS_PER_COMPILER"); do
        job_script="jobs/stdlib-${compiler}-${run}.sh"

        if [ ! -f "$job_script" ]; then
            echo "ERROR: Job script not found: $job_script"
            echo "Run 'make jobs' first to generate job scripts."
            exit 1
        fi

        echo "Submitting ${compiler}-${run}..."

        # Submit job and capture job ID
        job_id=$(sbatch --parsable "$job_script")

        if [ $? -eq 0 ]; then
            job_ids+=("$job_id")
            job_names+=("${compiler}-${run}")
            echo "  Job ID: $job_id"
        else
            echo "  ERROR: Failed to submit job"
            exit 1
        fi
    done
done

echo ""
echo "============================================="
echo "All jobs submitted successfully!"
echo "============================================="
echo "Total jobs: ${#job_ids[@]}"
echo ""

# Save job IDs to file for monitoring
{
    echo "# Job IDs for Stdlib Compilation Benchmark"
    echo "# Format: job_id compiler-run"
    for i in "${!job_ids[@]}"; do
        echo "${job_ids[$i]} ${job_names[$i]}"
    done
} > job_ids.txt

echo "Job IDs saved to: job_ids.txt"
echo ""
echo "Monitor jobs with:"
echo "  make status"
echo "  squeue -u \$USER"
echo ""
echo "Collect results when complete with:"
echo "  make collect"

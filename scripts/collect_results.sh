#!/bin/bash

# =============================================================================
# Collect and Aggregate Results from SLURM Jobs
# =============================================================================

# Change to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

# Configuration comes from environment variables (set by Makefile)

echo "Collecting Stdlib Compilation Benchmark Results"
echo "================================================"
echo ""

# Create summary directory
mkdir -p summary

# Initialize combined results file
combined_file="summary/combined_results.csv"
echo "compiler,run,compilation_time_seconds,job_id,node,timestamp" > "$combined_file"

# Track found and missing results
results_found=0
missing_results=()
error_results=()

# Collect results from each job
for compiler in $COMPILERS; do
    echo "Collecting results for compiler: $compiler"

    for run in $(seq 1 "$RUNS_PER_COMPILER"); do
        result_file="results/stdlib-${compiler}-${run}.csv"

        if [ -f "$result_file" ]; then
            # Check if the file has actual data (not just header)
            line_count=$(wc -l < "$result_file")

            if [ "$line_count" -gt 1 ]; then
                # Check if there's an ERROR in the compilation time field
                if grep -q ",ERROR," "$result_file"; then
                    error_results+=("${compiler}-${run}")
                    echo "  [ERROR] ${compiler}-${run} - Build failed"
                else
                    # Skip header and append to combined file
                    tail -n +2 "$result_file" >> "$combined_file"
                    results_found=$((results_found + 1))
                    echo "  [✓] ${compiler}-${run}"
                fi
            else
                missing_results+=("${compiler}-${run}")
                echo "  [EMPTY] ${compiler}-${run} - File has no data"
            fi
        else
            missing_results+=("${compiler}-${run}")
            echo "  [MISSING] ${compiler}-${run}"
        fi
    done
    echo ""
done

echo "================================================"
echo "Results Summary:"
echo "================================================"
total_expected=$(echo "$(echo "$COMPILERS" | wc -w) * $RUNS_PER_COMPILER" | bc)
echo "Found: $results_found/$total_expected successful result files"

if [ ${#error_results[@]} -gt 0 ]; then
    echo ""
    echo "⚠ Build errors: ${#error_results[@]}"
    echo "Jobs with build errors: ${error_results[@]}"
    echo ""
    echo "Check SLURM error logs for details:"
    for error in "${error_results[@]}"; do
        echo "  ls -lt slurm-${error}-*.err"
    done
fi

if [ ${#missing_results[@]} -gt 0 ]; then
    echo ""
    echo "⚠ Missing results: ${#missing_results[@]}"
    echo "Missing: ${missing_results[@]}"
    echo ""
    echo "Check job status with: make status"
    echo ""
    echo "Check SLURM error logs:"
    for missing in "${missing_results[@]}"; do
        echo "  ls -lt slurm-${missing}-*.err 2>/dev/null | head -1"
    done

    if [ $results_found -lt 2 ]; then
        echo ""
        echo "ERROR: Insufficient results for statistical analysis (need at least 2)."
        exit 1
    fi
else
    echo ""
    echo "✓ All results collected successfully!"
    echo "Combined results saved to: $combined_file"
    echo ""
    echo "Total data points: $(tail -n +2 "$combined_file" | wc -l)"
    echo ""

    # Show basic statistics
    echo "Quick preview:"
    echo "------------------------------------------------"
    for compiler in $COMPILERS; do
        times=$(grep "^${compiler}," "$combined_file" | cut -d',' -f3)
        if [ -n "$times" ]; then
            count=$(echo "$times" | wc -l)
            avg=$(echo "$times" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
            min=$(echo "$times" | sort -n | head -1)
            max=$(echo "$times" | sort -n | tail -1)
            echo "$compiler: n=$count, avg=${avg}s, min=${min}s, max=${max}s"
        fi
    done
    echo "------------------------------------------------"
    echo ""
    echo "Run statistical analysis with:"
    echo "  make analyze"
fi

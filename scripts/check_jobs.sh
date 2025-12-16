#!/bin/bash

# =============================================================================
# Check SLURM Job Status
# =============================================================================

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

echo "Stdlib Compilation Benchmark - Job Status"
echo "=========================================="
echo ""

if [ ! -f job_ids.txt ]; then
    echo "ERROR: job_ids.txt not found."
    echo "Submit jobs first with: make submit"
    exit 1
fi

# Read job IDs and names
mapfile -t lines < job_ids.txt

# Filter out comments and empty lines
declare -a job_ids
declare -a job_names

for line in "${lines[@]}"; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    job_id=$(echo "$line" | awk '{print $1}')
    job_name=$(echo "$line" | awk '{print $2}')

    job_ids+=("$job_id")
    job_names+=("$job_name")
done

echo "Checking ${#job_ids[@]} jobs..."
echo ""

# Count jobs by status
pending=0
running=0
completed=0
failed=0

# Check each job
for i in "${!job_ids[@]}"; do
    job_id="${job_ids[$i]}"
    job_name="${job_names[$i]}"

    # Query job status from sacct
    status=$(sacct -j "$job_id" --format=State --noheader 2>/dev/null | head -1 | tr -d ' ')

    if [ -z "$status" ]; then
        # Job might still be pending/running, check squeue
        status=$(squeue -j "$job_id" --format=%T --noheader 2>/dev/null | tr -d ' ')

        if [ -z "$status" ]; then
            status="UNKNOWN"
        fi
    fi

    # Categorize status
    case "$status" in
        PENDING)
            pending=$((pending + 1))
            ;;
        RUNNING|CONFIGURING)
            running=$((running + 1))
            ;;
        COMPLETED)
            completed=$((completed + 1))
            ;;
        FAILED|CANCELLED|TIMEOUT|NODE_FAIL|OUT_OF_MEMORY|PREEMPTED)
            failed=$((failed + 1))
            ;;
    esac

    # Format status with color if possible
    case "$status" in
        PENDING)
            status_display="[⏳ $status]"
            ;;
        RUNNING|CONFIGURING)
            status_display="[▶️  $status]"
            ;;
        COMPLETED)
            status_display="[✓ $status]"
            ;;
        FAILED|CANCELLED|TIMEOUT|NODE_FAIL|OUT_OF_MEMORY|PREEMPTED)
            status_display="[✗ $status]"
            ;;
        *)
            status_display="[? $status]"
            ;;
    esac

    printf "%-20s %s (Job ID: %s)\n" "$status_display" "$job_name" "$job_id"
done

echo ""
echo "========================================"
echo "Summary:"
echo "========================================"
echo "  Pending:   $pending"
echo "  Running:   $running"
echo "  Completed: $completed"
echo "  Failed:    $failed"
echo "  Total:     ${#job_ids[@]}"
echo ""

if [ $completed -eq ${#job_ids[@]} ]; then
    echo "✓ All jobs completed! Ready to collect results:"
    echo "  make collect"
elif [ $failed -gt 0 ]; then
    echo "⚠ WARNING: Some jobs failed. Check SLURM output files:"
    echo "  ls -lt slurm-*.err | head"
    echo ""
    echo "Failed jobs:"
    for i in "${!job_ids[@]}"; do
        job_id="${job_ids[$i]}"
        job_name="${job_names[$i]}"
        status=$(sacct -j "$job_id" --format=State --noheader 2>/dev/null | head -1 | tr -d ' ')
        if [ -z "$status" ]; then
            status=$(squeue -j "$job_id" --format=%T --noheader 2>/dev/null | tr -d ' ')
        fi
        case "$status" in
            FAILED|CANCELLED|TIMEOUT|NODE_FAIL|OUT_OF_MEMORY|PREEMPTED)
                echo "  - $job_name (Job ID: $job_id): $status"
                ;;
        esac
    done
else
    echo "⏳ Jobs still running. Check again with:"
    echo "  make status"
    echo ""
    echo "Or monitor continuously with:"
    echo "  watch -n 10 'make status'"
fi

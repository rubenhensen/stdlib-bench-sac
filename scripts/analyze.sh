#!/bin/bash

# =============================================================================
# Statistical Analysis of Benchmark Results
# =============================================================================

# Change to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

# Configuration comes from environment variables (set by Makefile)

COMBINED_FILE="summary/combined_results.csv"
OUTPUT_MD="summary/analysis.md"

if [ ! -f "$COMBINED_FILE" ]; then
    echo "ERROR: Combined results file not found: $COMBINED_FILE"
    echo "Run 'make collect' first."
    exit 1
fi

echo "Performing Statistical Analysis"
echo "================================"
echo ""

# Create markdown report header
cat > "$OUTPUT_MD" << 'EOF'
# Stdlib Compilation Time Benchmark Analysis

This report compares the compilation time of the SaC Standard Library between two compiler versions.

## Benchmark Configuration

EOF

# Add configuration details
echo "- **Compilers Tested**: $COMPILERS" >> "$OUTPUT_MD"
echo "- **Runs per Compiler**: $RUNS_PER_COMPILER" >> "$OUTPUT_MD"
echo "- **Build Targets**: $BUILD_TARGETS" >> "$OUTPUT_MD"
echo "- **Build System**: $BUILD_SYSTEM" >> "$OUTPUT_MD"
echo "- **SLURM Partition**: $SLURM_PARTITION" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

# Add summary statistics table header
cat >> "$OUTPUT_MD" << 'EOF'
## Summary Statistics

| Compiler | Mean (s) | Std Dev (s) | Min (s) | Max (s) | 95% CI | N |
|----------|----------|-------------|---------|---------|--------|---|
EOF

# Extract compilation times and calculate statistics for each compiler
declare -A compiler_stats

for compiler in $COMPILERS; do
    times=$(grep "^${compiler}," "$COMBINED_FILE" | cut -d',' -f3)

    if [ -z "$times" ]; then
        echo "WARNING: No data found for compiler: $compiler"
        continue
    fi

    # Calculate statistics using awk
    stats=$(echo "$times" | awk '
    {
        sum += $1
        times[NR] = $1
        if (NR == 1 || $1 < min) min = $1
        if (NR == 1 || $1 > max) max = $1
    }
    END {
        n = NR
        avg = sum / n

        # Calculate standard deviation
        for (i = 1; i <= n; i++) {
            sumsq += (times[i] - avg)^2
        }
        stddev = sqrt(sumsq / n)

        # Calculate 95% confidence interval
        # Using t-distribution critical value (approximation)
        if (n <= 5) t_crit = 2.776
        else if (n <= 10) t_crit = 2.262
        else if (n <= 20) t_crit = 2.093
        else t_crit = 1.96

        ci_margin = t_crit * stddev / sqrt(n)

        printf "%.2f %.2f %.2f %.2f %.2f %d", avg, stddev, min, max, ci_margin, n
    }')

    read avg stddev min max ci_margin n <<< "$stats"

    # Store for later use
    compiler_stats["${compiler}_avg"]=$avg
    compiler_stats["${compiler}_stddev"]=$stddev
    compiler_stats["${compiler}_min"]=$min
    compiler_stats["${compiler}_max"]=$max
    compiler_stats["${compiler}_ci"]=$ci_margin
    compiler_stats["${compiler}_n"]=$n

    echo "| $compiler | $avg | $stddev | $min | $max | ±$ci_margin | $n |" >> "$OUTPUT_MD"

    echo "Compiler '$compiler': avg=${avg}s, stddev=${stddev}s, n=${n}"
done

# Perform t-test using Python
echo ""
echo "Running t-test comparison..."

# Get compiler names as array
compiler_array=($COMPILERS)
if [ ${#compiler_array[@]} -eq 2 ]; then
    compiler1="${compiler_array[0]}"
    compiler2="${compiler_array[1]}"

    echo "" >> "$OUTPUT_MD"
    echo "## Statistical Comparison (Independent T-Test)" >> "$OUTPUT_MD"
    echo "" >> "$OUTPUT_MD"

    $PYTHON << PYTHON_SCRIPT >> "$OUTPUT_MD"
import csv
import sys

try:
    import scipy.stats as stats
    import numpy as np
except ImportError:
    print("ERROR: scipy or numpy not installed.")
    print("Run 'make venv' to setup the Python environment.")
    sys.exit(1)

# Read data
data = {'$compiler1': [], '$compiler2': []}

try:
    with open('$COMBINED_FILE', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            compiler = row['compiler']
            time = float(row['compilation_time_seconds'])
            if compiler in data:
                data[compiler].append(time)
except Exception as e:
    print(f"ERROR: Failed to read CSV file: {e}")
    sys.exit(1)

# Convert to numpy arrays
data1 = np.array(data['$compiler1'])
data2 = np.array(data['$compiler2'])

if len(data1) == 0 or len(data2) == 0:
    print("ERROR: Insufficient data for comparison.")
    sys.exit(1)

# Perform independent t-test
t_stat, p_value = stats.ttest_ind(data1, data2)

# Calculate means and speedup
mean1 = np.mean(data1)
mean2 = np.mean(data2)
speedup = mean2 / mean1 if mean1 > 0 else 0

# Determine significance and winner
significant = 'YES' if p_value < 0.05 else 'NO'
if p_value >= 0.05:
    winner = 'TIE (not statistically significant)'
elif mean1 < mean2:
    winner = '$compiler1 (faster)'
else:
    winner = '$compiler2 (faster)'

# Output results
print("### Results")
print("")
print(f"- **T-statistic**: {t_stat:.4f}")
print(f"- **P-value**: {p_value:.6f}")
print(f"- **Statistically Significant (α=0.05)**: {significant}")
print(f"- **Mean Compilation Time ($compiler1)**: {mean1:.2f} seconds")
print(f"- **Mean Compilation Time ($compiler2)**: {mean2:.2f} seconds")
print(f"- **Speedup Ratio**: {speedup:.4f}x ($compiler2 / $compiler1)")
print(f"- **Winner**: {winner}")
print("")

# Interpretation
print("### Interpretation")
print("")
if p_value < 0.05:
    faster = '$compiler1' if mean1 < mean2 else '$compiler2'
    slower = '$compiler2' if mean1 < mean2 else '$compiler1'
    pct_diff = abs((mean2 - mean1) / mean1 * 100)
    print(f"The results show a **statistically significant difference** (p < 0.05) between the two compilers.")
    print(f"The **{faster}** compiler is approximately **{pct_diff:.1f}% faster** than {slower}.")
else:
    print(f"The results show **no statistically significant difference** (p ≥ 0.05) between the two compilers at the 95% confidence level.")
    print(f"Any observed difference in mean compilation times is likely due to random variation.")
PYTHON_SCRIPT

    if [ $? -ne 0 ]; then
        echo "ERROR: Python analysis failed"
        exit 1
    fi
else
    echo "" >> "$OUTPUT_MD"
    echo "## Note" >> "$OUTPUT_MD"
    echo "" >> "$OUTPUT_MD"
    echo "Statistical comparison requires exactly 2 compilers. Found: ${#compiler_array[@]}" >> "$OUTPUT_MD"
fi

# Add timestamp and cluster info
echo "" >> "$OUTPUT_MD"
echo "---" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"
echo "**Generated**: $(date)" >> "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

# Try to get cluster name
cluster_name=$(scontrol show config 2>/dev/null | grep ClusterName | cut -d'=' -f2 | tr -d ' ')
if [ -n "$cluster_name" ]; then
    echo "**Cluster**: $cluster_name" >> "$OUTPUT_MD"
fi

echo ""
echo "================================"
echo "Analysis complete!"
echo "================================"
echo "Report saved to: $OUTPUT_MD"
echo ""
echo "View report:"
echo "  cat $OUTPUT_MD"
echo "  less $OUTPUT_MD"

#!/bin/bash

# =============================================================================
# Export Analysis Results to JSON
# =============================================================================

# Change to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

# Configuration comes from environment variables (set by Makefile)

COMBINED_FILE="summary/combined_results.csv"
OUTPUT_JSON="summary/analysis.json"

if [ ! -f "$COMBINED_FILE" ]; then
    echo "ERROR: Combined results file not found: $COMBINED_FILE"
    exit 1
fi

echo "Generating JSON analysis..."

$PYTHON << 'PYTHON_SCRIPT'
import csv
import json
import os
import sys

try:
    import scipy.stats as stats
    import numpy as np
except ImportError:
    print("ERROR: scipy or numpy not installed.")
    print("Run 'make venv' to setup the Python environment.")
    sys.exit(1)

combined_file = os.environ['COMBINED_FILE']
output_json = os.environ['OUTPUT_JSON']
compilers = os.environ['COMPILERS'].split()

# Read data
data = {c: [] for c in compilers}
all_rows = []

try:
    with open(combined_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            compiler = row['compiler']
            time = float(row['compilation_time_seconds'])
            if compiler in data:
                data[compiler].append(time)
            all_rows.append(row)
except Exception as e:
    print(f"ERROR: Failed to read CSV file: {e}")
    sys.exit(1)

# Calculate statistics for each compiler
results = {
    'config': {
        'compilers': compilers,
        'runs_per_compiler': int(os.environ.get('RUNS_PER_COMPILER', 10)),
        'build_targets': os.environ.get('BUILD_TARGETS', ''),
        'build_system': os.environ.get('BUILD_SYSTEM', ''),
    },
    'compilers': {}
}

for compiler in compilers:
    if len(data[compiler]) == 0:
        continue

    times = np.array(data[compiler])

    # Calculate 95% CI
    n = len(times)
    if n <= 5:
        t_crit = 2.776
    elif n <= 10:
        t_crit = 2.262
    elif n <= 20:
        t_crit = 2.093
    else:
        t_crit = 1.96

    std_dev = float(np.std(times, ddof=1))
    ci_margin = t_crit * std_dev / np.sqrt(n)

    results['compilers'][compiler] = {
        'mean': float(np.mean(times)),
        'std_dev': std_dev,
        'min': float(np.min(times)),
        'max': float(np.max(times)),
        'ci_95': float(ci_margin),
        'n': int(n),
        'raw_times': times.tolist()
    }

# Perform t-test if we have exactly 2 compilers
if len(compilers) == 2:
    c1, c2 = compilers

    if len(data[c1]) > 0 and len(data[c2]) > 0:
        data1 = np.array(data[c1])
        data2 = np.array(data[c2])

        t_stat, p_value = stats.ttest_ind(data1, data2)

        mean1 = np.mean(data1)
        mean2 = np.mean(data2)
        speedup = float(mean2 / mean1) if mean1 > 0 else 0

        # Determine winner
        if p_value >= 0.05:
            winner = 'TIE'
        elif mean1 < mean2:
            winner = c1
        else:
            winner = c2

        results['comparison'] = {
            't_statistic': float(t_stat),
            'p_value': float(p_value),
            'significant': bool(p_value < 0.05),
            'speedup': speedup,
            'winner': winner,
            'interpretation': (
                f"{winner} is faster" if winner != 'TIE'
                else "No statistically significant difference"
            )
        }

# Save to JSON
try:
    with open(output_json, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"JSON analysis saved to: {output_json}")
except Exception as e:
    print(f"ERROR: Failed to write JSON file: {e}")
    sys.exit(1)
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    echo "JSON export complete!"
else
    echo "ERROR: JSON export failed"
    exit 1
fi

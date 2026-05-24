#!/bin/bash
# End-to-end orchestrator: generate -> submit -> wait -> retry -> collect -> report.
# Runs from the project root; everything else lives under Makefile-controlled steps.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

# Banner
echo "============================================================"
echo "Stdlib Compilation Benchmark — one-shot run"
echo "============================================================"
echo "Compilers          : ${COMPILERS}"
echo "Runs per compiler  : ${RUNS_PER_COMPILER}"
echo "Build targets      : ${BUILD_TARGETS}"
echo "SLURM partition    : ${SLURM_PARTITION}"
echo "Max retry rounds   : ${MAX_RETRIES}"
echo "============================================================"
echo

# 1. Fresh job scripts
make --no-print-directory jobs

# 2. Submit
make --no-print-directory submit

# 3. Wait until SLURM thinks everything is done
make --no-print-directory wait

# 4. Auto-retry rounds: keep retrying failed runs until either success or cap
attempt=0
while (( attempt < MAX_RETRIES )); do
  attempt=$(( attempt + 1 ))
  echo
  echo "------------------------------------------------------------"
  echo "Retry round ${attempt}/${MAX_RETRIES}"
  echo "------------------------------------------------------------"
  if make --no-print-directory retry; then
    echo "Nothing to retry — all runs succeeded."
    break
  fi
  make --no-print-directory wait
done

# 5. Collect + report (always run, even with residual failures)
echo
make --no-print-directory collect
echo
make --no-print-directory report

echo
echo "============================================================"
echo "Done. Open:"
echo "  summary/report.md           (human report)"
echo "  summary/thesis_snippet.typ  (paste into the thesis)"
echo "  summary/analysis.json       (machine-readable stats)"
echo "  summary/metadata.json       (reproducibility footer)"
echo "============================================================"

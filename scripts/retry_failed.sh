#!/bin/bash
# Detect runs that did not finish SUCCESSfully and resubmit just those tasks.
#
# Detection rule: for every (compiler, run) in the matrix, the run is
# "missing" if results/stdlib-<compiler>-<run>.json is absent or its
# status field is not "SUCCESS".
#
# Resubmission: builds a comma-separated array spec per compiler and
# submits a new sbatch with --array=<that spec>, reusing the existing
# jobs/stdlib-<compiler>.array.sh script.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

PY="${PYTHON:-python3}"

ANY_RESUBMITTED=0

for compiler in ${COMPILERS}; do
  failures=()
  for run in $(seq 1 "${RUNS_PER_COMPILER}"); do
    file="results/stdlib-${compiler}-${run}.json"
    if [[ ! -f "${file}" ]]; then
      failures+=("${run}")
      continue
    fi
    status="$("${PY}" -c "import json,sys; print(json.load(open(sys.argv[1])).get('status',''))" "${file}" 2>/dev/null || echo "")"
    if [[ "${status}" != "SUCCESS" ]]; then
      failures+=("${run}")
    fi
  done

  if [[ ${#failures[@]} -eq 0 ]]; then
    echo "[retry] compiler '${compiler}': all ${RUNS_PER_COMPILER} runs SUCCESS"
    continue
  fi

  # Remove the stale failure JSONs so the retry overwrites them cleanly
  for r in "${failures[@]}"; do
    rm -f "results/stdlib-${compiler}-${r}.json"
  done

  array_spec="$(IFS=,; echo "${failures[*]}")"
  if [[ -n "${SLURM_ARRAY_CONCURRENCY:-}" ]]; then
    array_spec="${array_spec}%${SLURM_ARRAY_CONCURRENCY}"
  fi

  script="jobs/stdlib-${compiler}.array.sh"
  echo "[retry] compiler '${compiler}': resubmitting ${#failures[@]} task(s) -> --array=${array_spec}"
  jid="$(sbatch --parsable --array="${array_spec}" "${script}")"
  echo "${jid}  ${compiler}  ${array_spec}  $(date -Iseconds)  RETRY" >> job_ids.txt
  ANY_RESUBMITTED=1
done

# Exit code 0 = nothing to retry. Exit code 1 = at least one retry was submitted.
exit ${ANY_RESUBMITTED}

#!/bin/bash
# Generate one SLURM array script per compiler.
#
# Inputs (env vars set by the Makefile):
#   COMPILERS, RUNS_PER_COMPILER, BUILD_TARGETS, BUILD_SYSTEM,
#   SLURM_TIMELIMIT, SLURM_CPUS, SLURM_MEM, SLURM_ACCOUNT, SLURM_PARTITION,
#   SLURM_ARRAY_CONCURRENCY,
#   SAC2C_NEW_SLURM, SAC2C_ORIG_SLURM,
#   SAC2C_NEW_DIR_SLURM, SAC2C_ORIG_DIR_SLURM,
#   SAC2C_NEW_SRC_SLURM, SAC2C_ORIG_SRC_SLURM,
#   STDLIB_SRC_SLURM,
#   TEMP_ROOT_PREFERRED, TEMP_ROOT_FALLBACK
#
# Output: jobs/stdlib-<compiler>.array.sh (one per compiler)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

mkdir -p jobs

ARRAY_SPEC="1-${RUNS_PER_COMPILER}"
if [[ -n "${SLURM_ARRAY_CONCURRENCY:-}" ]]; then
  ARRAY_SPEC="${ARRAY_SPEC}%${SLURM_ARRAY_CONCURRENCY}"
fi

for compiler in ${COMPILERS}; do
  case "${compiler}" in
    new)
      SAC2C_PATH="${SAC2C_NEW_SLURM}"
      SAC2C_DIR="${SAC2C_NEW_DIR_SLURM}"
      SAC2C_SRC="${SAC2C_NEW_SRC_SLURM:-}"
      ;;
    orig)
      SAC2C_PATH="${SAC2C_ORIG_SLURM}"
      SAC2C_DIR="${SAC2C_ORIG_DIR_SLURM}"
      SAC2C_SRC="${SAC2C_ORIG_SRC_SLURM:-}"
      ;;
    *)
      echo "ERROR: unknown compiler '${compiler}' (extend generate_jobs.sh)" >&2
      exit 1
      ;;
  esac

  JOB_NAME="stdlib-${compiler}"
  OUT="jobs/${JOB_NAME}.array.sh"

  sed -e "s|__COMPILER__|${compiler}|g" \
      -e "s|__JOB_NAME__|${JOB_NAME}|g" \
      -e "s|__ARRAY_SPEC__|${ARRAY_SPEC}|g" \
      -e "s|__SAC2C_PATH__|${SAC2C_PATH}|g" \
      -e "s|__SAC2C_DIR__|${SAC2C_DIR}|g" \
      -e "s|__SAC2C_SRC__|${SAC2C_SRC}|g" \
      -e "s|__STDLIB_SRC__|${STDLIB_SRC_SLURM}|g" \
      -e "s|__BUILD_TARGETS__|${BUILD_TARGETS}|g" \
      -e "s|__BUILD_SYSTEM__|${BUILD_SYSTEM}|g" \
      -e "s|__TIMELIMIT__|${SLURM_TIMELIMIT}|g" \
      -e "s|__CPUS__|${SLURM_CPUS}|g" \
      -e "s|__MEM__|${SLURM_MEM}|g" \
      -e "s|__ACCOUNT__|${SLURM_ACCOUNT}|g" \
      -e "s|__PARTITION__|${SLURM_PARTITION}|g" \
      -e "s|__TEMP_ROOT_PREFERRED__|${TEMP_ROOT_PREFERRED:-/scratch}|g" \
      -e "s|__TEMP_ROOT_FALLBACK__|${TEMP_ROOT_FALLBACK:-\$HOME}|g" \
      job_template.sh > "${OUT}"
  chmod +x "${OUT}"
  echo "wrote ${OUT}  (array ${ARRAY_SPEC})"
done

echo
echo "Done. Submit with: make submit  (or 'make run' for one-command end-to-end)"

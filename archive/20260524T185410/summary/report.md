# Stdlib Compilation Time Benchmark — Report

_Generated: 2026-05-24T18:53:24_

## Summary statistics (SUCCESS runs only)

| Compiler | N | Mean (s) | Std Dev (s) | 95% CI (±s) | Min (s) | Max (s) | Median (s) |
|---|---:|---:|---:|---:|---:|---:|---:|
| new | 0 | — | — | — | — | — | — |
| orig | 2 | 2330.73 | 15.64 | 140.51 | 2319.67 | 2341.79 | 2330.73 |

### Peak resident-set memory (kB, GNU `/usr/bin/time -v`)

| Compiler | N | Mean | Std Dev | Min | Max |
|---|---:|---:|---:|---:|---:|
| new | 0 | — | — | — | — |
| orig | 2 | 3859732 | 51 | 3859696 | 3859768 |

## Failed runs

| Compiler | Run | Status | Exit | Node |
|---|---:|---|---|---|
| new | 1 | ERROR | 2 | cn58 |
| new | 2 | ERROR | 2 | cn58 |

## Statistical comparison (Welch's t-test)

Not enough data for a two-compiler comparison.

## Reproducibility metadata

### SLURM

- Partition: `cncz`
- Account: `csmpi`
- CPUs per task: `4`
- Memory requested: `14G`
- Wall-clock cap: `02:00:00`
- Node(s) used: `cn58`

### Host environment

- CPU: `Intel(R) Xeon(R) CPU E5-2630L v3 @ 1.80GHz`
- Total memory (kB): `32764296`
- Kernel: `6.8.0-110-generic`
- OS: `Ubuntu 24.04.4 LTS`
- GCC: `gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`
- CMake: `cmake version 3.28.3`

### Compilers

#### `new`

- Path: `/home/rhensen/sac2c/build_p/sac2c_p`
- Commit: `f2870cfeac931033f66bf11ab827beee08030327`
- Branch: `progressive-dispatch-clean`
- `git describe`: `v2.1.0-PuurGeluk-327-gf2870cfea`
- `sac2c -V`: sac2c 2.1.0-PuurGeluk-327-gf2870 / build-type: RELEASE / built-by: "rhensen" at 2026-05-24T17:49:38 / 

#### `orig`

- Path: `/home/rhensen/sacoriginal/sac2c/build_p/sac2c_p`
- Commit: `ab3bbecacf1a978daf64b88cabc4b9df53d4b2e8`
- Branch: `develop`
- `git describe`: `v2.1.0-PuurGeluk-269-gab3bbecac`
- `sac2c -V`: sac2c 2.1.0-PuurGeluk-269-gab3bb / build-type: RELEASE / built-by: "rhensen" at 2026-05-24T17:37:57 / 

### Stdlib

- Path: `/home/rhensen/Stdlib`
- Commit: `9afffd46db51fd6877048f34fbd6c5a5de5eede5`
- Branch: `master`

### Build

- Compilers: `new orig`
- Runs per compiler: `2`
- Build targets: `seq;mt_pth`
- Build system: `make`
- Per-build temp directory: `~/tmp_stdlib_build_<compiler>_<run>_<jobid>_<task>` (deleted after timing)
- Measurement: wall-clock via `date +%s.%N` around `cmake … && make -j N`; peak RSS via GNU `/usr/bin/time -v`.

_Started: 2026-05-24T18:10:28+00:00 — Finished: 2026-05-24T18:52:05+00:00_

Source data: `summary/combined_results.csv` (slim, one row per task), `summary/all_runs.json` (full per-run records), `summary/metadata.json` (this footer).
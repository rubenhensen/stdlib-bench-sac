# Stdlib Compilation Time Benchmark Analysis

This report compares the compilation time of the SaC Standard Library between two compiler versions.

## Benchmark Configuration

- **Compilers Tested**: new orig
- **Runs per Compiler**: 32
- **Build Targets**: seq;mt_pth
- **Build System**: make
- **SLURM Partition**: csmpi_fpga_long

## Summary Statistics

| Compiler | Mean (s) | Std Dev (s) | Min (s) | Max (s) | 95% CI | N |
|----------|----------|-------------|---------|---------|--------|---|
| new | 945.33 | 11.83 | 925.13 | 968.63 | ±4.10 | 32 |
| orig | 960.00 | 11.20 | 941.00 | 976.28 | ±3.94 | 31 |

## Statistical Comparison (Independent T-Test)

### Results

- **T-statistic**: -4.9703
- **P-value**: 0.000006
- **Statistically Significant (α=0.05)**: YES
- **Mean Compilation Time (new)**: 945.33 seconds
- **Mean Compilation Time (orig)**: 960.00 seconds
- **Speedup Ratio**: 1.0155x (orig / new)
- **Winner**: new (faster)

### Interpretation

The results show a **statistically significant difference** (p < 0.05) between the two compilers.
The **new** compiler is approximately **1.6% faster** than orig.

---

**Generated**: Tue Dec 16 02:49:04 PM CET 2025

**Cluster**: science

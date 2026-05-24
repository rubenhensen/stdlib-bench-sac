#!/bin/bash
# Produce the final reproducibility-complete report:
#   summary/report.md           — human-readable, with metadata footer
#   summary/analysis.json       — t-test + per-compiler stats (machine-readable)
#   summary/thesis_snippet.typ  — paste-ready Typst table + caption template
#
# Inputs: summary/combined_results.csv, summary/all_runs.json, summary/metadata.json.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

mkdir -p summary

PY="${PYTHON:-python3}"

"${PY}" - <<'PY'
import csv, json, os, sys
from datetime import datetime

try:
    import numpy as np
    import scipy.stats as stats
except ImportError:
    sys.stderr.write("ERROR: numpy/scipy missing. Run 'make venv'.\n")
    sys.exit(1)

CSV  = "summary/combined_results.csv"
META = "summary/metadata.json"
REPORT_MD     = "summary/report.md"
ANALYSIS_JSON = "summary/analysis.json"
SNIPPET_TYP   = "summary/thesis_snippet.typ"

with open(META) as f:
    meta = json.load(f)

# Load per-run data
rows = []
with open(CSV) as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

compilers = meta["config"]["compilers"]
runs_per  = meta["config"]["runs_per_compiler"]

# Group times by compiler, only SUCCESS rows count toward statistics
times = {c: [] for c in compilers}
peak_rss = {c: [] for c in compilers}
for r in rows:
    c = r["compiler"]
    if c not in times: continue
    if r.get("status") != "SUCCESS": continue
    t = r.get("compilation_time_seconds")
    if t in (None, "", "null"): continue
    try:
        times[c].append(float(t))
    except ValueError:
        continue
    rss = r.get("peak_rss_kb")
    if rss not in (None, "", "null"):
        try:
            peak_rss[c].append(float(rss))
        except ValueError:
            pass

# Failed runs per compiler, with reason
failed = {c: [] for c in compilers}
for r in rows:
    c = r["compiler"]
    if c not in failed: continue
    if r.get("status") != "SUCCESS":
        failed[c].append({
            "run": int(r["run"]),
            "status": r.get("status",""),
            "exit_code": r.get("exit_code",""),
            "node": r.get("node",""),
        })

# Per-compiler stats
def summarise(arr):
    arr = np.asarray(arr, dtype=float)
    n = arr.size
    if n == 0:
        return None
    mean = float(arr.mean())
    sd   = float(arr.std(ddof=1)) if n >= 2 else 0.0
    sem  = sd / np.sqrt(n) if n >= 2 else 0.0
    # Use exact t critical value for the actual degrees of freedom
    t_crit = float(stats.t.ppf(0.975, df=n-1)) if n >= 2 else 0.0
    ci    = t_crit * sem
    return {
        "n": n,
        "mean": mean,
        "std_dev": sd,
        "sem": sem,
        "ci95_margin": ci,
        "min": float(arr.min()),
        "max": float(arr.max()),
        "median": float(np.median(arr)),
        "raw": arr.tolist(),
    }

stats_by_compiler = {c: summarise(times[c]) for c in compilers}
rss_by_compiler   = {c: summarise(peak_rss[c]) for c in compilers}

# Independent t-test (Welch) between the two compilers if we have exactly two
comparison = None
if len(compilers) == 2 and all(stats_by_compiler[c] for c in compilers):
    c1, c2 = compilers
    a = np.asarray(times[c1], dtype=float)
    b = np.asarray(times[c2], dtype=float)
    t_stat, p_val = stats.ttest_ind(a, b, equal_var=False)
    speedup = float(b.mean() / a.mean()) if a.mean() > 0 else 0.0
    significant = bool(p_val < 0.05)
    if not significant:
        winner = "TIE"
    elif a.mean() < b.mean():
        winner = c1
    else:
        winner = c2
    comparison = {
        "compiler_a": c1, "compiler_b": c2,
        "t_statistic": float(t_stat),
        "p_value": float(p_val),
        "alpha": 0.05,
        "significant": significant,
        "speedup_b_over_a": speedup,
        "winner": winner,
    }

analysis = {
    "stats": stats_by_compiler,
    "peak_rss_kb_stats": rss_by_compiler,
    "comparison": comparison,
    "failed_runs": failed,
}
with open(ANALYSIS_JSON, "w") as f:
    json.dump(analysis, f, indent=2, sort_keys=True)

# ----------------------------- Markdown report ------------------------------
out = []
w = out.append
w(f"# Stdlib Compilation Time Benchmark — Report")
w("")
w(f"_Generated: {datetime.now().isoformat(timespec='seconds')}_")
w("")
w("## Summary statistics (SUCCESS runs only)")
w("")
w("| Compiler | N | Mean (s) | Std Dev (s) | 95% CI (±s) | Min (s) | Max (s) | Median (s) |")
w("|---|---:|---:|---:|---:|---:|---:|---:|")
for c in compilers:
    s = stats_by_compiler.get(c)
    if not s:
        w(f"| {c} | 0 | — | — | — | — | — | — |")
        continue
    w(f"| {c} | {s['n']} | {s['mean']:.2f} | {s['std_dev']:.2f} | {s['ci95_margin']:.2f} | "
      f"{s['min']:.2f} | {s['max']:.2f} | {s['median']:.2f} |")

w("")
w("### Peak resident-set memory (kB, GNU `/usr/bin/time -v`)")
w("")
w("| Compiler | N | Mean | Std Dev | Min | Max |")
w("|---|---:|---:|---:|---:|---:|")
for c in compilers:
    s = rss_by_compiler.get(c)
    if not s:
        w(f"| {c} | 0 | — | — | — | — |")
        continue
    w(f"| {c} | {s['n']} | {s['mean']:.0f} | {s['std_dev']:.0f} | {s['min']:.0f} | {s['max']:.0f} |")
w("")

# Failures
any_fail = any(failed[c] for c in compilers)
w("## Failed runs")
w("")
if not any_fail:
    w("None. Every requested run reached SUCCESS.")
else:
    w("| Compiler | Run | Status | Exit | Node |")
    w("|---|---:|---|---|---|")
    for c in compilers:
        for f_ in failed[c]:
            w(f"| {c} | {f_['run']} | {f_['status']} | {f_['exit_code']} | {f_['node']} |")
w("")

# Comparison
w("## Statistical comparison (Welch's t-test)")
w("")
if comparison is None:
    w("Not enough data for a two-compiler comparison.")
else:
    w(f"- Compilers compared: **{comparison['compiler_a']}** vs **{comparison['compiler_b']}**")
    w(f"- t = {comparison['t_statistic']:.4f}, p = {comparison['p_value']:.6g}, α = 0.05")
    w(f"- Statistically significant: **{'YES' if comparison['significant'] else 'NO'}**")
    w(f"- Mean speedup ({comparison['compiler_b']}/{comparison['compiler_a']}): {comparison['speedup_b_over_a']:.4f}×")
    w(f"- Winner: **{comparison['winner']}**")
w("")

# Reproducibility footer
w("## Reproducibility metadata")
w("")
slurm = meta.get("slurm", {})
hw    = meta.get("hardware", {})
w("### SLURM")
w("")
w(f"- Partition: `{slurm.get('partition','')}`")
w(f"- Account: `{slurm.get('account','')}`")
w(f"- CPUs per task: `{slurm.get('cpus_per_task','')}`")
w(f"- Memory requested: `{slurm.get('mem_requested','')}`")
w(f"- Wall-clock cap: `{slurm.get('timelimit_requested','')}`")
nodes = hw.get("nodes_used", [])
if nodes:
    w(f"- Node(s) used: {', '.join(f'`{n}`' for n in nodes)}")
w("")

w("### Host environment")
w("")
for k, label in [("cpu_model","CPU"),
                  ("total_memory_kb","Total memory (kB)"),
                  ("kernel","Kernel"),
                  ("os_release","OS"),
                  ("gcc_version","GCC"),
                  ("cmake_version","CMake")]:
    v = hw.get(k, "")
    if v:
        w(f"- {label}: `{v}`")
w("")

w("### Compilers")
w("")
for c in compilers:
    cinfo = meta.get("compilers", {}).get(c, {})
    w(f"#### `{c}`")
    w("")
    w(f"- Path: `{cinfo.get('sac2c_path','')}`")
    w(f"- Commit: `{cinfo.get('sac2c_commit','') or '(no .git found)'}`")
    w(f"- Branch: `{cinfo.get('sac2c_branch','')}`")
    w(f"- `git describe`: `{cinfo.get('sac2c_describe','')}`")
    ver = (cinfo.get('sac2c_version_raw','') or '').replace('|', ' / ')
    if ver:
        w(f"- `sac2c -V`: {ver}")
    w("")

stdlib = meta.get("stdlib", {})
w("### Stdlib")
w("")
w(f"- Path: `{stdlib.get('src_path','')}`")
w(f"- Commit: `{stdlib.get('commit','') or '(no .git found)'}`")
w(f"- Branch: `{stdlib.get('branch','')}`")
w("")

w("### Build")
w("")
cfg = meta.get("config", {})
w(f"- Compilers: `{' '.join(cfg.get('compilers', []))}`")
w(f"- Runs per compiler: `{cfg.get('runs_per_compiler','')}`")
w(f"- Build targets: `{cfg.get('build_targets','')}`")
w(f"- Build system: `{cfg.get('build_system','')}`")
w(f"- Per-build temp directory: `~/tmp_stdlib_build_<compiler>_<run>_<jobid>_<task>` (deleted after timing)")
w(f"- Measurement: wall-clock via `date +%s.%N` around `cmake … && {cfg.get('build_system','make')} -j N`; peak RSS via GNU `/usr/bin/time -v`.")
w("")

if meta.get("warnings"):
    w("### Warnings emitted during collection")
    w("")
    for warn in meta["warnings"]:
        w(f"- {warn}")
    w("")

w(f"_Started: {meta.get('started_at','?')} — Finished: {meta.get('finished_at','?')}_")
w("")
w("Source data: `summary/combined_results.csv` (slim, one row per task), "
  "`summary/all_runs.json` (full per-run records), `summary/metadata.json` (this footer).")

with open(REPORT_MD, "w") as f:
    f.write("\n".join(out))

# --------------------- Thesis-ready Typst table snippet ---------------------
# Mirrors the existing thesis table format (Compiler | Mean | Std Dev | Min | Max | 95% CI).
snippet = []
sw = snippet.append
sw("// Auto-generated by stdlib-bench-sac/scripts/generate_report.sh")
sw("// Paste into the thesis, then adjust caption wording if needed.")
sw("")
sw("#figure(")
sw("  table(")
sw("    columns: 7,")
sw("    align: (left, right, right, right, right, right, right),")
sw("    table.header(")
sw("      [Compiler], [N], [Mean (s)], [Std Dev (s)], [Min (s)], [Max (s)], [95% CI]")
sw("    ),")
for c in compilers:
    s = stats_by_compiler.get(c)
    if not s:
        sw(f"    [{c}], [0], [—], [—], [—], [—], [—],")
        continue
    sw(f"    [{c.capitalize() if c=='new' else c.capitalize()}], "
       f"[{s['n']}], [{s['mean']:.2f}], [{s['std_dev']:.2f}], "
       f"[{s['min']:.2f}], [{s['max']:.2f}], [±{s['ci95_margin']:.2f}],")
sw("  ),")

# Caption with full reproducibility info
node_str = ", ".join(nodes) if nodes else "the SLURM node listed in @hardware"
sw(f"  caption: [Standard library compilation time on {node_str} ")
sw(f"           (partition `{slurm.get('partition','?')}`, "
   f"{slurm.get('cpus_per_task','?')} CPUs, "
   f"{slurm.get('mem_requested','?')} memory, "
   f"wall-clock cap {slurm.get('timelimit_requested','?')}). ")

c_blurbs = []
for c in compilers:
    s = stats_by_compiler.get(c)
    cinfo = meta.get("compilers", {}).get(c, {})
    c_blurbs.append(f"`{c}` compiler N={s['n'] if s else 0} "
                    f"(commit `{(cinfo.get('sac2c_commit','')[:12]) or '?'}`)")
sw(f"           {', '.join(c_blurbs)}. ")
sw(f"           Stdlib commit `{(stdlib.get('commit','')[:12]) or '?'}`. ")
sw(f"           Targets `{cfg.get('build_targets','')}`. ")
if comparison and comparison["significant"]:
    sw(f"           Welch's t-test: t={comparison['t_statistic']:.2f}, "
       f"p={comparison['p_value']:.2g} (significant at α=0.05); "
       f"{comparison['winner']} is faster on average. ")
elif comparison:
    sw(f"           Welch's t-test: t={comparison['t_statistic']:.2f}, "
       f"p={comparison['p_value']:.2g} (not significant at α=0.05). ")

# Honest failure disclosure
fail_lines = []
for c in compilers:
    if failed[c]:
        fail_lines.append(f"{c}: {len(failed[c])} failed (runs {', '.join(str(f['run']) for f in failed[c])})")
if fail_lines:
    sw(f"           Failures: {'; '.join(fail_lines)}. ")
sw(f"           Raw per-run data in appendix (@stdlib-raw).],")
sw(") <stdlib-res>")

with open(SNIPPET_TYP, "w") as f:
    f.write("\n".join(snippet) + "\n")

print(f"wrote {REPORT_MD}")
print(f"wrote {ANALYSIS_JSON}")
print(f"wrote {SNIPPET_TYP}")
PY

#!/bin/bash
# Aggregate per-task JSON files into a single combined CSV + per-batch metadata.
#
# Outputs:
#   summary/combined_results.csv  (slim, one row per task)
#   summary/all_runs.json         (full per-run records)
#   summary/metadata.json         (batch-level reproducibility footer)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

mkdir -p summary
PY="${PYTHON:-python3}"

"${PY}" - <<'PY'
import csv, glob, json, os, sys
from collections import defaultdict, Counter

compilers = os.environ.get("COMPILERS", "new orig").split()
runs_per  = int(os.environ.get("RUNS_PER_COMPILER", "0"))

records = []
for path in sorted(glob.glob("results/stdlib-*-*.json")):
    try:
        with open(path) as f:
            records.append(json.load(f))
    except Exception as e:
        print(f"WARN: could not parse {path}: {e}", file=sys.stderr)

# Slim CSV — convenient for spreadsheets and quick eyeballing.
csv_cols = ["compiler", "run", "status", "exit_code",
            "compilation_time_seconds", "peak_rss_kb",
            "user_cpu_s", "sys_cpu_s",
            "job_id", "array_task_id", "node",
            "started_at", "finished_at"]
with open("summary/combined_results.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=csv_cols, extrasaction="ignore")
    w.writeheader()
    for r in records:
        w.writerow(r)

# Full JSON, one object per task.
with open("summary/all_runs.json", "w") as f:
    json.dump(records, f, indent=2, sort_keys=True)

# Batch-level metadata: dedup across tasks, warn on divergence.
def first_nonempty(vs):
    for v in vs:
        if v: return v
    return ""

batch = {
    "config": {
        "compilers": compilers,
        "runs_per_compiler": runs_per,
        "build_targets": os.environ.get("BUILD_TARGETS", ""),
        "build_system": os.environ.get("BUILD_SYSTEM", ""),
    },
    "slurm": {
        "partition": os.environ.get("SLURM_PARTITION", ""),
        "account":   os.environ.get("SLURM_ACCOUNT", ""),
        "cpus_per_task":      os.environ.get("SLURM_CPUS", ""),
        "mem_requested":      os.environ.get("SLURM_MEM", ""),
        "timelimit_requested":os.environ.get("SLURM_TIMELIMIT", ""),
    },
    "hardware": {},
    "compilers": {},
    "stdlib": {},
    "totals": {},
    "warnings": [],
}

if records:
    def field(name):
        seen = []
        for r in records:
            v = r.get(name, "")
            if v and v not in seen:
                seen.append(v)
        return seen

    for h in ["cpu_model", "total_memory_kb", "kernel", "os_release",
              "gcc_version", "cmake_version"]:
        vs = field(h)
        if not vs:
            continue
        batch["hardware"][h] = vs[0]
        if len(vs) > 1:
            batch["warnings"].append(f"hardware.{h} varied across tasks: {vs}")

    nodes = sorted({r.get("node", "") for r in records if r.get("node")})
    batch["hardware"]["nodes_used"] = nodes
    if len(nodes) > 1:
        batch["warnings"].append(f"runs landed on multiple nodes: {nodes}")

    for c in compilers:
        rs = [r for r in records if r.get("compiler") == c]
        if not rs:
            continue
        batch["compilers"][c] = {
            "sac2c_path":      first_nonempty([r.get("sac2c_path", "") for r in rs]),
            "sac2c_version_raw": first_nonempty([r.get("sac2c_version_raw", "") for r in rs]),
            "sac2c_commit":    first_nonempty([r.get("sac2c_commit", "") for r in rs]),
            "sac2c_branch":    first_nonempty([r.get("sac2c_branch", "") for r in rs]),
            "sac2c_describe":  first_nonempty([r.get("sac2c_describe", "") for r in rs]),
        }

    batch["stdlib"] = {
        "src_path": first_nonempty([r.get("stdlib_src", "") for r in records]),
        "commit":   first_nonempty([r.get("stdlib_commit", "") for r in records]),
        "branch":   first_nonempty([r.get("stdlib_branch", "") for r in records]),
    }

    status_counts = Counter(r.get("status", "?") for r in records)
    per_compiler = defaultdict(Counter)
    for r in records:
        per_compiler[r.get("compiler", "?")][r.get("status", "?")] += 1
    batch["totals"] = {
        "records": len(records),
        "by_status": dict(status_counts),
        "by_compiler": {c: dict(v) for c, v in per_compiler.items()},
    }

    starts = [r.get("started_at", "") for r in records if r.get("started_at")]
    ends   = [r.get("finished_at", "") for r in records if r.get("finished_at")]
    if starts: batch["started_at"]  = min(starts)
    if ends:   batch["finished_at"] = max(ends)

with open("summary/metadata.json", "w") as f:
    json.dump(batch, f, indent=2, sort_keys=True)

print(f"collected {len(records)} run record(s)")
print("  -> summary/combined_results.csv")
print("  -> summary/all_runs.json")
print("  -> summary/metadata.json")

if records:
    print()
    print("Per-compiler outcome:")
    for c in compilers:
        cs = per_compiler.get(c, Counter())
        ok = cs.get("SUCCESS", 0)
        bad = sum(v for k,v in cs.items() if k != "SUCCESS")
        print(f"  {c}: SUCCESS={ok}, others={bad}  ({dict(cs)})")
PY

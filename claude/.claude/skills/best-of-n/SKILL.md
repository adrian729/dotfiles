---
name: best-of-n
description: Generate N independent solutions from different angles, judge against rubric, synthesize best parts. Use when user says "best of N" (any number), "tournament", "contest between approaches"; NOT when user wants one-shot implementation or single-review audit (→ implementer or audit-loop).
---

# Best-of-N

Spawn workers with different angles, judge against rubric, synthesize best parts. Works for any task type and any AI tool.

## 1. Set N
- User specifies → use that.
- Otherwise propose: critical → 7, standard → 5. State reasoning, user confirms.
- Higher defaults add diversity at zero API cost — free workers (opencode, ollama) supplement Claude under Claude Code; more agent variety under OpenCode. N counts all workers.

## 2. Set worker distribution

Free workers count toward N, not on top. Task type → agent pool varies by tool.

### Tool: Claude Code

| Task type | Workers |
|---|---|
| Implementation | `implementer-quick` / `implementer` / `implementer-deep` |
| Planning/architecture | `planner-quick` / `planner` / `planner-deep` |
| Writing/docs | `writer-quick` / `writer` / `writer-deep` |
| Research | `researcher-quick` / `researcher` / `researcher-deep` |
| Debugging | `debugger-quick` / `debugger` / `debugger-deep` |
| Mixed / unknown | Ask user |

Free pool: `opencode-task` (full coding agent in worktree), `llm` (local ollama, text-only), `opencode-llm` (free cloud, text-only).

| N | Free | Claude workers | Free workers |
|---|---|---|---|
| 1–2 | 0 | Existing formula for N | — |
| 3 | 1 | Formula for N=2: 1 quick + 1 base | 1 opencode-task |
| 4 | 1 | Formula for N=3: 1 quick + 1 base + 1 deep | 1 opencode-task |
| 5 | 1 | Formula for N=4: 1 quick + 2 base + 1 deep | 1 opencode-task |
| 6 | 2 | Formula for N=4: 1 quick + 2 base + 1 deep | 1 opencode-task + 1 llm/opencode-llm |
| 7 | 2 | Formula for N=5: 1 quick + 2 base + 1 deep + 1 effort-* | 1 opencode-task + 1 llm/opencode-llm |

Beyond N=7: free = min(floor(N/3), 2), Claude = tier formula for (N − free_count).

### Tool: OpenCode

| Task type | Workers |
|---|---|
| Implementation | `implementer-quick` / `implementer` |
| Planning | `planner` |
| Research | `researcher` |
| Debugging | `debugger` |
| Review | `reviewer-quick` / `reviewer` |
| Audit | `auditor` |
| Text / cheap | `relay` / `llm` / `opencode-llm` |

No Claude models — all workers from opencode agents or ollama.

| N | Workers |
|---|---|
| 1 | 1 quick (`implementer-quick` / `reviewer-quick`) |
| 2 | 1 quick + 1 base (`implementer`) |
| 3 | 1 quick + 1 base + 1 text (`relay` / `llm`) |
| 4 | 1 quick + 1 base + 1 text + 1 specialist per task type |
| 5+ | Above + 1 additional specialist per extra N |

## 3. Define angles
- N distinct approaches from the task. State each, user confirms.

## 4. Define rubric
- Extract evaluation criteria from task acceptance criteria.
- Each criterion: weight (1–5) + score (1–10). User confirms.

## 5. Spawn workers

### Tool: Claude Code
- Spawn Claude workers via Agent tool. Each gets: task + its angle + output path. No worker sees others' outputs.
- Spawn free workers via `run_in_background` for each bash call, at the same time as Claude workers:
  - `opencode-task best-of-n-{angle} -T {timeout} "task + angle"` → response on stdout, changes in `.worktrees/best-of-n-{angle}/`. Write response to `.best-of-n-outputs/{angle}.md`.
  - `echo "task + angle" | llm --code -o .best-of-n-outputs/{angle}.md "spec"` — local ollama text-only
  - `echo "task + angle" | opencode-llm -o .best-of-n-outputs/{angle}.md "spec"` — free cloud text-only
- On free worker failure (opencode/ollama unavailable, timeout) → treat as no output, continue with remaining.

### Tool: OpenCode
- Spawn workers via `opencode run --agent <name> --auto -- "prompt + angle"`. Write response to `.best-of-n-outputs/{angle}.md`.
- Text-only: `llm "instruction"` or `opencode-llm -o .best-of-n-outputs/{angle}.md "spec"`.
- Each gets: task + its angle + output path. No cross-contamination. Never use Claude models.

## 6. Score
- Judge receives rubric + all N outputs (primary + free workers).
- Auditor agent for critical tasks; reviewer otherwise.
- Scores each per criterion with reasoning — free workers scored on same rubric, no special treatment.

## 7. Synthesize
- Combine best parts from all outputs into final result.
- No clear winner → present tradeoffs.

## 8. Report
- Scoring matrix (criteria × solutions), synthesized output, provenance per part (which tool produced each).
- Note which workers were free (opencode/ollama) and cost savings.
- State upfront: cost estimate before user confirms.

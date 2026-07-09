---
name: best-of-n
description: Generate N independent solutions from different angles, judge against rubric, synthesize best parts. Use when user says "best of N" (any number), "tournament", "contest between approaches"; NOT when user wants one-shot implementation or single-review audit (→ implementer or audit-loop).
---

# Best-of-N

Spawn workers with different angles, judge against rubric, synthesize best parts. Works for any task type.

## 1. Set N
- User specifies → use that.
- Otherwise propose: critical → 5, standard → 3. State reasoning, user confirms.

## 2. Set worker distribution
Task type → agent pool:

| Task type | Workers |
|---|---|
| Implementation | `implementer-quick` / `implementer` / `implementer-deep` |
| Planning/architecture | `planner-quick` / `planner` / `planner-deep` |
| Writing/docs | `writer-quick` / `writer` / `writer-deep` |
| Research | `researcher-quick` / `researcher` / `researcher-deep` |
| Debugging | `debugger-quick` / `debugger` / `debugger-deep` |
| Mixed / unknown | Ask user |

N=1 → 1 quick. N=2 → 1 quick + 1 base. N=3 → 1 quick + 1 base + 1 deep. N=4 → 1 quick + 2 base + 1 deep. N=5 → 1 quick + 2 base + 1 deep + 1 effort-*. User confirms.

## 3. Define angles
- N distinct approaches from the task. State each, user confirms.

## 4. Define rubric
- Extract evaluation criteria from task acceptance criteria.
- Each criterion: weight (1–5) + score (1–10). User confirms.

## 5. Spawn workers
- Same-session subagent dispatch via spawn tools.
- Each gets: task + its angle + output path.
- No worker sees others' outputs.
- Set timeout per worker.

## 6. Score
- Judge receives rubric + all outputs.
- Auditor agent for critical tasks; reviewer otherwise.
- Scores each per criterion with reasoning.

## 7. Synthesize
- Combine best parts into final output.
- No clear winner → present tradeoffs.

## 8. Report
- Scoring matrix (criteria × solutions), synthesized output, provenance per part.
- State upfront: ~2.5× single-run cost before user confirms.
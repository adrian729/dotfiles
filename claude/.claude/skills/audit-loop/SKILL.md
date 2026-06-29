---
name: audit-loop
description: Iteratively audit work: find issues, fix the safe ones, re-audit until two consecutive clean passes (or a user-given iteration cap). Use ONLY for repeating/looping audits — e.g. "audit loop", "keep auditing until it's clean", "audit and fix until two clean passes", "iteratively audit". Do NOT trigger on a one-shot "audit", "review", "harden", or "double-check" with no looping intent — those are /code-review or /security-review. The user may, in plain language, ask to split across parallel subagents and/or cap iterations.
---

# Audit Loop

Repeatedly find issues, fix the safe ones, and re-audit until the work is genuinely clean. Run hands-off; report at the end.

## 1. Target
- Named in the request → audit exactly that.
- Else → audit the most recent work this session (analysis, plan, implementation, updates), inferred from context.
- State the target in one line before starting.

## 2. Options (natural language, no flags — infer intent, not exact keywords)
- **Iteration cap** — a number ("max 5", "cap at 3", "at most 4 rounds", "stop after N") → hard cap. Otherwise no cap; rely on convergence.
- **Split** — any ask to parallelize / divide / use subagents → run split mode (§6). Use the parts they name, else propose a decomposition.

## 3. Dimensions (adapt to target)
- **Code** → correctness & bugs, security, edge cases, missing/weak tests, simplification & reuse. Reuse `/code-review` and `/security-review`; `/simplify` for cleanup-only findings; `/verify` to confirm behavior.
- **Plan / analysis / design** → completeness vs intent, contradictions, unstated assumptions, missing edge cases, feasibility.
- **Docs / updates** → accuracy vs actual code/state, internal consistency, stale/broken references.

Surface real issues, not nitpicks.

## 4. Loop
Track `iteration = 0`, `clean_streak = 0`. Log every iteration.

Repeat:
1. `iteration += 1`
2. Audit across the dimensions. Output each issue with location + severity.
3. Issues found → `clean_streak = 0`. Per issue: apply the fix now if in-scope and low-risk; else skip and record why (risky / ambiguous / out-of-scope / needs user decision). Log issues + applied fixes + skipped fixes.
4. No issues → `clean_streak += 1`.
5. **Stop** when EITHER `clean_streak == 2` (two consecutive clean passes — never stop on one) OR a cap was given and `iteration == cap`.

Two clean passes because a fix in iteration N can introduce a new issue caught in N+1.

**Deferred-only pass** — a pass that finds issues but auto-fixes none (all skipped) does NOT count toward the clean streak.

**Stall guard** — if a pass's only remaining issues were already skipped last iteration and no new fix is possible, stop and mark the run "stalled". This is in addition to the two-clean rule.

## 5. Report (always)
- **Target** + **mode** (single / split into N).
- **Per iteration**: issues found, fixes applied, fixes skipped + reason.
- **Outcome**: total iterations + why it stopped (2 clean / cap reached / stalled).
- **Needs your attention**: every deferred fix, with its reason.

## 6. Split mode (subagents)
1. Partition into **non-overlapping** parts (the user's, or a decomposition you state) — each owns a distinct file set so parallel fixes can't collide in the shared working tree.
2. One code-capable subagent per part, given this procedure (§3–§5) scoped strictly to its part, with the same cap. Each loops to convergence and returns a structured sub-report (target, per-iteration issues/fixes/skips, outcome).
3. Run them in parallel (single message, multiple Agent calls).
4. Scopes can't separate cleanly (parts share files) → say so, then re-partition or fall back to a single-context loop; never let two subagents edit the same file.
5. Aggregate all sub-reports into one §5 report. Optionally run one short integration pass over the seams between parts.

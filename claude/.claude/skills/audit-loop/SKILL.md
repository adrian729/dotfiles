---
name: audit-loop
description: >-
  Iteratively audit work — find issues, fix the safe ones, re-audit, and repeat until
  two consecutive clean passes (or a max-iterations cap). Use when the user says "audit
  loop", "run an audit loop", asks to audit / harden / double-check recent work, or names
  a target to audit. Can split the audit across parallel subagents.
argument-hint: "[target] [--max N] [--split: part-a, part-b, ...]"
---

# Audit Loop

A convergent audit: repeatedly find issues, fix the safe ones, and re-audit until the
work is genuinely clean. Default to running it hands-off and reporting at the end.

## 1. Determine the target
- If the user named a target (in `$ARGUMENTS` or their message), audit exactly that.
- Otherwise audit whatever we were just working on this session — the most recent
  analysis, plan, implementation, or set of updates. Infer it from recent context.
- State the target in one line before starting.

## 2. Parse options
- `--max N` — hard cap on iterations. Absent → no cap; rely on convergence.
- `--split` (optionally with a comma-separated list of parts) — run as parallel
  subagents, one per part (see §6).

## 3. Pick audit dimensions (adapt to the target)
- **Code / implementation** → correctness & bugs, security, edge cases, missing/weak
  tests, simplification & reuse. Reuse the existing `/code-review` and `/security-review`
  skills here; use `/simplify` for cleanup-only findings and `/verify` to confirm behavior.
- **Plan / analysis / design** → completeness vs intent, internal contradictions,
  unstated assumptions, missing edge cases, feasibility.
- **Docs / updates** → accuracy vs the actual code/state, internal consistency, stale or
  broken references.
Surface real issues, not nitpicks.

## 4. The loop
Track `iteration = 0` and `clean_streak = 0`. Keep a running log of every iteration.

Repeat:
1. `iteration += 1`
2. Audit the target across the chosen dimensions. Output concrete issues — each with
   location and severity.
3. If issues are found:
   - `clean_streak = 0`
   - For each issue: **apply the fix now** if it is in-scope and low-risk. Otherwise
     **skip it and record why** (risky / ambiguous / out-of-scope / needs a user decision).
   - Log this iteration's issues + applied fixes + skipped fixes (with reasons).
4. If no issues are found: `clean_streak += 1`.
5. **Stop** when EITHER:
   - `clean_streak == 2` — two consecutive clean passes (never stop on one), OR
   - `--max` was set and `iteration == max`.

Why two clean passes: a fix in iteration N can introduce a new issue caught in N+1, so a
single clean pass isn't proof of convergence.

**Deferred-only pass:** if a pass finds issues but every one is deferred (nothing
auto-fixed), it does NOT count toward the clean streak.

**Stall guard (safety):** if an iteration's only remaining issues are ones already skipped
in the previous iteration and no new fix is possible, stop and mark the run "stalled" —
don't loop forever on un-fixable findings. This is in addition to, not instead of, the
two-clean rule.

## 5. Final report (always)
End with:
- **Target** audited and **mode** (single / split into N).
- **Per iteration**: issues found, fixes applied, fixes skipped + reason.
- **Outcome**: total iterations and why it stopped (converged on 2 clean / max reached /
  stalled).
- **Needs your attention**: every deferred fix, called out clearly with its reason.

## 6. Split mode (subagents)
When `--split` is requested:
1. Partition the work into **non-overlapping** parts — the parts the user named, or a
   decomposition you propose and state. Each part must own a distinct set of files so
   parallel fixes cannot collide in the shared working tree.
2. Spawn one code-capable subagent per part. Give each subagent THIS procedure (§3–§5)
   scoped strictly to its part, including the same `--max`. Each subagent runs its own
   loop to convergence and returns a structured sub-report (target, per-iteration
   issues/fixes/skips, outcome).
3. Run them in parallel (single message, multiple Agent calls).
4. If scopes can't be cleanly separated (parts share files), say so and either
   re-partition or fall back to a single-context loop — never let two subagents edit the
   same file.
5. Aggregate all sub-reports into one §5 report. Optionally run one short integration
   pass over the seams between parts.

---
name: audit-loop
description: Iteratively audit work: find issues, fix safe ones, re-audit until two consecutive clean passes (or user-given iteration cap). Use ONLY for repeating/looping audits — e.g. "audit loop", "keep auditing until it's clean", "audit and fix until two clean passes", "iteratively audit". Do NOT trigger on one-shot "audit", "review", "harden", or "double-check" with no looping intent — those are /code-review or /security-review. User may, in plain language, ask to split across parallel subagents and/or cap iterations.
---

# Audit Loop

Repeatedly find issues, fix safe ones, and re-audit until work is genuinely clean. Run hands-off; report at the end.

## 1. Target
- Named in request → audit exactly that.
- Else → audit most recent work this session (analysis, plan, implementation, updates), inferred from context.
- State target in one line before starting.

## 2. Options (natural language, no flags — infer intent, not exact keywords)
- **Iteration cap** — number ("max 5", "cap at 3", "at most 4 rounds", "stop after N") → hard cap. Otherwise no cap; rely on convergence.
- **Split** — any ask to parallelize / divide / use subagents → run split mode (§7). Use parts they name, else propose decomposition.

## 3. Dimensions (adapt to target)
- **Code** → correctness & bugs, security, edge cases, missing/weak tests, simplification & reuse. Auditor runs `/code-review` and `/security-review`; cleanup-only findings are minors (report may suggest `/simplify` as a decision option); parent runs `/verify` on applied fixes.
- **Plan / analysis / design** → completeness vs intent, contradictions, unstated assumptions, missing edge cases, feasibility.
- **Docs / updates** → accuracy vs actual code/state, internal consistency, stale/broken references.

## 4. Findings & severity
- Every finding: location, severity, one-line summary. Blocking additionally: concrete failure scenario (inputs/state → wrong outcome; plans/docs: concrete decision or reader misled).
- **blocking** — bugs, security, correctness gaps, contradictions, missing requirements: real impact. Resets clean streak; fixed or explicitly deferred.
- **minor** — style, naming, cosmetic, marginal improvements: no concrete failure scenario. Never resets streak, never auto-fixed, never looped on → ledger, deduped by parent (same location — modulo line drift from fixes — + same underlying issue → one entry, wording aside).
- Clean pass = zero blocking findings after triage; minor-only pass counts clean.

## 5. Loop
Track `iteration = 0`, `clean_streak = 0`, minor ledger, deferred list. Log every iteration.

Repeat:
1. `iteration += 1`
2. **Audit** — spawn fresh auditor subagent (`reviewer`; `auditor` when user asked for audit-grade/security rigor; `auditor-deep` for explicit maximum/exhaustive rigor or the most safety-critical targets) — never audit in own context. Prompt must state: read-only, report findings, never edit files; for code targets only, run `/code-review`/`/security-review` fully in-context (no nested subagents), non-code targets → dimensions alone; clean is a valid, expected outcome — do not manufacture findings; no severity inflation; finding contract (§4). Provide: target scope, dimensions, contract, current deferred list (mark re-sightings, don't re-report as new). Do NOT provide own reasoning or prior-iteration findings. Target exists only in conversation → serialize first (embed full text in prompt, or scratch file + path).
3. **Triage** — per blocking finding: missing or unsound failure scenario → downgrade to minor or reject, log reason. User asked for paranoid/thorough → adversarial verification instead: independent skeptic subagent per blocking finding, prompted to refute.
4. Surviving blocking findings → `clean_streak = 0`. Per finding: in-scope and low-risk → fix now, then `/verify`; else defer + record reason (risky / ambiguous / out-of-scope / needs user decision). Minors → ledger.
5. No surviving blocking findings → `clean_streak += 1`. Re-sighted deferred finding counts as unresolved blocking — that pass is NOT clean.
6. **Stop** when EITHER `clean_streak == 2` (two consecutive clean passes — never stop on one) OR cap was given and `iteration == cap`.

Two clean passes because fix in iteration N can introduce new issue caught in N+1.

**Deferred-only pass** — pass whose only blocking findings are deferred (no fix applied) does NOT count toward clean streak.

**Stall guard** — only remaining blocking issues were already deferred previously AND no new fix is possible → stop, mark run "stalled". Deferred finding that became fixable → re-triage, don't stall. This is in addition to the two-clean rule.

## 6. Report (always)
- **Target** + **mode** (single / split into N).
- **Per iteration**: blocking found / fixed / deferred + reasons, downgrades + reasons.
- **Outcome**: total iterations + why it stopped (2 clean / cap reached / stalled).
- **Needs your attention**: every deferred finding, with its reason.
- **Minor findings (non-blocking)**: deduped ledger, location + one-liner each; reader decides — fix now, run another loop including them (selected minors become explicit requirements of the new run's target, i.e. blocking if unmet), or ignore. Never silently dropped.

## 7. Split mode (subagents)
1. Partition into **non-overlapping** parts (the user's, or decomposition you state) — each owns distinct file set.
2. Per iteration: one fresh auditor per part in parallel (single message, multiple Agent calls; same auditor rules as §5 step 2) → parent triages all findings → parallel fixer subagents only for parts with surviving blocking findings; never dispatch two fixers at one file.
3. **Ownership** — auditors may report findings outside their part (`/code-review` sees the whole diff): reassign each finding to the part owning its file, dedupe across auditors. Blocking finding reassigned to a retired part → reopen it (`clean_streak = 0`, rejoins loop), unless re-sighting of its own deferred finding (stays deferred). Blocking in a file owned by no part → parent fixes directly if low-risk, else defers to parent-held "no part" deferred list (passed to next-pass auditors like any part's); unowned minors → ledger, "no part" bucket.
4. **Fixers** return per-finding fixed / deferred + reason — feeds the part's deferred list and stall condition — and run `/verify` on their own fixes before returning.
5. Per-part `clean_streak`: part **retires** at 2 clean passes (converged) or its own stall condition (stalled); others keep looping. Run ends when all parts retired or shared cap hit.
6. Scopes can't separate cleanly (parts share files) → say so, then re-partition or fall back to single-context loop; never let two subagents edit same file.
7. Aggregate into one §6 report; per-part minor ledgers merged, deduped, grouped by part. Optionally one short integration pass over seams.

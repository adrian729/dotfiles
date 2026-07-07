---
name: audit-loop
description: Iteratively audit work: find issues, fix safe ones, re-audit until two consecutive clean passes (or given cap). Use when "audit loop", "keep auditing until clean", "iteratively audit"; NOT when one-shot audit/review/harden/double-check (those → reviewer/auditor). User may cap iterations.
---

# Audit Loop

Repeatedly find issues, fix safe ones, re-audit until clean. Run hands-off; report at end.

## 1. Target
- Named in request → audit exactly that.
- Else → most recent work this session (analysis, plan, implementation, docs), inferred from context.
- State target in one line before starting.

## 2. Options (natural language, no flags)
- **Iter cap** — number ("max 5", "cap at 3") → hard cap. Otherwise no cap; rely on convergence.
- **Split mode** — see §9.

## 3. Agents

| Step | Default agent | Escalated agent |
|------|--------------|-----------------|
| Audit | per tier table (§4) | per tier table |
| Triage | `analyzer` (sonnet medium) | `analyzer-deep` (opus high) for paranoid mode |
| Fix | `implementer` (sonnet medium) | `implementer-deep` (opus high) for risky fixes |
| Report | `summarizer` (sonnet medium) | — |

Non-code targets use same agents — dimensions (§5) drive the focus, not agent body.

## 4. Tiers

| Mode | Trigger | Main loop audit | Confirmation (clean_streak==1) |
|------|---------|-----------------|-------------------------------|
| Quick/cheap | "quick", "cheap", "light" | `reviewer-quick` (sonnet med) | `reviewer` (sonnet xhigh) |
| Normal | (default) | `reviewer` (sonnet xhigh) | `auditor` (opus high) |
| Paranoid | "security", "thorough", "audit" | `auditor` (opus high) | `auditor-deep` (opus xhigh) |
| Maximum | "exhaustive", "leave no stone unturned" | `auditor-deep` (opus xhigh) | `auditor-deep` (fresh spawn) |

After confirmation fails → next iteration uses Main loop agent again (all tiers: Reset == Main).

## 5. Dimensions
Adapt to target type — pass relevant dimensions to auditor in its prompt:
- **Code** — correctness & bugs, edge cases, missing/weak tests, security (auditor only), simplification & reuse.
- **Plan/analysis/design** — completeness vs intent, contradictions, unstated assumptions, missing edge cases, feasibility.
- **Docs/updates** — accuracy vs actual code/state, internal consistency, stale/broken references.

## 6. Findings & severity
- Every finding: location, severity, one-line summary. Blocking additionally: concrete failure scenario (inputs/state → wrong outcome; plans/docs: concrete decision or reader misled).
- **blocking** — real impact: bugs, security, correctness gaps, contradictions, missing requirements. Resets clean streak; fixed or explicitly deferred.
- **minor** — style, naming, cosmetic, no concrete failure scenario. Never resets streak, never auto-fixed, never looped on → ledger, deduped by parent.
- Paranoid/max mode: all findings treated as blocking.
- Clean pass = zero blocking findings after triage; minor-only pass counts clean.

## 7. Loop
Track `iteration = 0`, `clean_streak = 0`, minor ledger, deferred list. Log every iteration.

Repeat:
1. `iteration += 1`
2. **Agent selection** — if `clean_streak == 1`, use Confirmation column from tier table. Otherwise use Main loop column.
3. **Audit** — spawn selected agent. Prompt: read-only, report findings, never edit files; target dimensions (§5). Provide: target scope, dimensions, current deferred list. Do NOT provide own reasoning or prior-iteration findings. Target exists only in conversation → serialize first (embed full text in prompt, or scratch file + path).
4. **Triage** — spawn `analyzer` with all findings + target scope + deferred list. Per finding: is it a re-sight of a deferred item? **First** re-sight → treat as blocking normally. **Second+** re-sight of same finding → mark non-blocking (noted for report, no action). Missing or unsound failure scenario → downgrade to minor or reject. Log all reasons. Paranoid mode → `analyzer-deep`.
5. Surviving blocking findings → `clean_streak = 0`. Per finding: in-scope and low-risk → fix via `implementer`; else defer + record reason (risky / ambiguous / out-of-scope / needs user decision). Minors → ledger.
6. No surviving blocking findings → `clean_streak += 1`.
7. **Stop** when EITHER `clean_streak == 2` (two consecutive clean passes — never stop on one) OR cap was given and `iteration == cap`.

**Stall guard** — only remaining blocked issues were already deferred AND no new fix possible → stop, "stalled". A deferred finding that became fixable → re-triage, don't stall. A pass whose only blocking findings are re-sighted deferreds with no new findings and no fixes applied contributes to stall detection.

## 8. Report (always)
Spawn `summarizer` with full iteration log. Output:
- **Target** + **mode** (tier used).
- **Per iteration**: blocking found / fixed / deferred + reasons, downgrades + reasons, clean_streak, agents used.
- **Outcome**: total iterations + why stopped (2 clean / cap reached / stalled).
- **Needs your attention**: every deferred finding, with its reason and re-sight count. Flag that deferred findings are unresolved and not minor — user decides.
- **Minor findings (non-blocking)**: deduped ledger, location + one-liner each; user decides — fix later or rerun loop including them.

## 9. Split mode
1. **Partition** — automatically decompose by directory boundary (no file in >1 part). If user names parts, use those. State each part's file set.
2. **Independent loops** — each part runs full sequential loop (§7) with own iteration count, clean_streak, deferred list. Auditors receive only their part's files. If an auditor reads outside files for context, it must only report findings on its own part's files.
3. **Seam scan** — after each part reaches `clean_streak == 2` independently, one sequential loop over boundary files (interfaces, shared modules, partition edges). Catches cross-cutting issues.
4. **Report** — merge all per-part reports + seam scan into single §8 report.

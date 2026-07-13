---
name: evaluator-optimizer
description: Generate→critique loop: generator produces the artifact fresh each round, an independently prompted evaluator on a different model scores it against one fixed rubric, until pass or iteration cap (default 3, max 5), then escalate. Use when "evaluator-optimizer", "generator-critic loop", "regenerate until the evaluator passes it", "have a different model judge it and iterate"; NOT when repairing existing work in place with layered criteria per pass (→ audit-loop) or generating N parallel attempts and picking the best (→ best-of-n).
---

# Evaluator-Optimizer Loop

Generator produces the artifact fresh each round; an uncorrelated evaluator scores it against one fixed rubric; stop on pass or cap, then escalate. One confirmation gate up front; hands-off after.

## 1. Intake & rubric
- Ask what to generate and how to evaluate. Convert vague criteria into a rubric: per criterion, one-line statement + binary pass/fail threshold. No weighted scores.
- Single confirmation gate before any generation: rubric, cap, tier/pairing, artifact location, cost estimate. Paid-model offer for a colliding OpenCode pairing (§3) happens here too.
- After confirmation the rubric is frozen — evaluator never adds/amends criteria; rubric defects escalate (§6).

## 2. Options (natural language, no flags)
- **Iter cap** — number given → clamp to [1, 5], say so when clamping; default 3.
- **Tier** — "quick"/"cheap" | (default) | "thorough"/"critical"/"deep" → column in §3 tables.
- **Pairing** — "claude-only" / "cross-family" override §3 precedence (Claude Code host only).
- **Artifact path** — where text artifacts live; else infer and state it.

## 3. Agent roles by tool

Evaluator is always a fresh, independently prompted spawn — never shared context, never the generator's conversation. Uncorrelation ladder (best first): different family > different tier > independently prompted instance; report which level was achieved.

### Tool: Claude Code

May mix Claude and OpenCode agents per role. Default: cheaper generates, stronger evaluates.

| Artifact | Generator (quick / default / deep) | Evaluator (quick / default / deep) |
|---|---|---|
| Code | `implementer-quick` (sonnet low) / `implementer` (sonnet medium) / `implementer-deep` (opus high) | `reviewer` (sonnet xhigh) / `auditor` (opus high) / `auditor-deep` (opus xhigh) |
| Plan/design | `planner-quick` (sonnet med) / `planner` (opus high) / `planner-deep` (opus xhigh) | same evaluator column |
| Docs/writing | `writer-quick` (sonnet low) / `writer` (sonnet med) / `writer-deep` (opus high) | same evaluator column |

Plan/design default and deep tiers tie generator/evaluator on model+effort — cross-family resolves the tie; cross-family unavailable → tie stands as "independently prompted instance", flag in report.

**Cross-family evaluator — precedence, re-checked each round, any row**: (1) user said "cross-family" → always; (2) user said "claude-only" → never; (3) pairing ties on model+effort → yes; (4) context ≥75% full (context-pressure routing) → prefer; (5) else → same-family evaluator column. Requires `opencode` CLI (`command -v opencode`); unavailable → same-family fallback (rule 1: tell user at gate) + flag in report. The §1 gate confirms pairing policy; the vehicle may switch mid-loop under these rules — record every switch. Rubric and cap never change.

**Cross-family mechanics**: evaluator = `opencode-task <name> --agent reviewer` (deep tier: `--agent auditor`) with explicit `-m <first available model from opencode-models free>` — never rely on the deployed agent binding (can silently be a paid model via install-probe fallback); paid only after the y/N/always gate.
- Name unique per run+iteration (`eval-opt-<slug>-<run-id>-iter<N>`, run-id from `$PPID`+date) — a reused name resumes a stale session and breaks evaluator independence.
- Serialize the artifact into the prompt (full diff or full text) — the worktree is cut from HEAD; uncommitted work is invisible there.
- After the verdict, discard worktree AND branch: `opencode-wt -d <name>` (or `git worktree remove`), then `git branch -D <name>` — the branch is never auto-deleted for unmerged throwaways.
- Free evaluator passing all criteria → one confirmation pass by `auditor` (opus high); AND-gate of two uncorrelated evaluators.
- opencode failure/timeout → same-family evaluator for that round; note in report.

### Tool: OpenCode

Strictly OpenCode agents; never Claude models.

| Artifact | Generator | Evaluator |
|---|---|---|
| Code | `implementer` (quick: `implementer-quick`) | `reviewer` (deep: `auditor`) |
| Plan/design | `planner` (all tiers) | `reviewer` (deep: `auditor`) |
| Docs | `implementer` (needs edit; no writer agent) | `reviewer` (deep: `auditor`) |

Tier mapping: "quick" changes only the generator and only in the Code row; evaluator is `reviewer` at quick/default and `auditor` at deep for every row — never `reviewer-quick` (model list byte-identical to `implementer-quick`). Don't re-derive other variants from the Claude Code table.

**Model-collision check (before loop)**: read actually-bound models per pairing from the deployed opencode.json `agent` block (or probe state under `~/.local/state/agents/`) — NOT the static `opencode-models agents <name>` list (skips live availability). Generator and evaluator on the same model (today: Plan/design row — planner/reviewer/auditor all bind `gpt-oss:120b-cloud`; implementer differs) → differentiation degrades to "independently prompted instance": say so in the report, and the passing round gets one confirmation pass by a fresh `auditor` spawn (prompt diversity only — never present it as a different model). Non-colliding rows: no caveat, no extra pass. True differentiation for a colliding pair needs a paid model (e.g. auditor→qwen3.7-max) — offer once at the §1 gate, default N.

Evaluators are tool-enforced read-only (`edit: deny`) — they report, never write.

## 4. Sprint contract
Generator's first spawn produces only a contract: scope (files/sections) + how each rubric criterion will be verifiably satisfied. Evaluator approves or rejects with per-point reasons — agent-side gate, no user. Max 2 revisions; still rejected → escalate to user. Approved contract is frozen and included in every later generator and evaluator prompt.

## 5. Loop
State: `iteration = 0`, `cap`, per-iteration verdicts, `best_iteration` (fewest failing criteria; tie → latest).
1. `iteration += 1`.
2. **Generate** — fresh spawn: task + contract + rubric + previous output + latest evaluator feedback. Complete replacement — regenerate, don't minimally patch. Code: rewrite the contract-named files in the working tree. Text: full rewrite of the artifact file. **Failure** (spawn error, empty output, ignores contract scope) → don't evaluate; retry once fresh within the same iteration; second consecutive failure → escalate "generator failure" with `best_iteration`. A retried-then-successful round consumes one iteration.
3. **Snapshot** — `.evaluator-optimizer/<run-id>/iter-N.diff` (code: `git diff`) or `iter-N.md` (text), repo root, both hosts. Keep untracked/ignored, never commit. Delete the dir after a pass report; keep on escalation until the user decides (say so in the report).
4. **Evaluate** — fresh spawn: rubric + contract + serialized artifact ONLY — no generator reasoning, no prior evaluations. Verdict format: per criterion `pass|fail` + one-line reasoning; each fail additionally a concrete failure scenario (inputs/state → wrong outcome) + what would satisfy the threshold. Judge the output, not intent; never write replacement content. **Failure** (spawn error or malformed verdict) → retry once (malformed: restate the format); second failure → switch evaluator vehicle (same-family ↔ cross-family) for this round; that fails too → escalate "evaluator failure" with `best_iteration`. Evaluator retries consume no iterations.
5. All pass → §6 Pass. Else check §6 in order: rubric defect → pause/escalate; `iteration == cap` → cap escalation; stall tripped → stall escalation; none → feedback → step 1. Never loop back unconditionally.

## 6. Stop & escalation
- **Pass** — all criteria pass + the applicable confirmation pass (Claude Code cross-family → `auditor` opus high; OpenCode collision mode → fresh `auditor` spawn). Confirmation fail = normal fail feedback consuming an iteration — unless already at cap, then it becomes the cap escalation (never exceed cap). Then → report.
- **Cap** — `iteration == cap` → present `best_iteration` snapshot + full trajectory, escalate to user.
- **Stall** — identical failing-criteria set for 2 consecutive rounds with nothing newly passing → stop early as "stalled", escalate.
- **Rubric defect** — evaluator flags a criterion unmeetable/contradictory → pause, escalate; rubric changes require re-confirmation (user decides re-run vs continue).

## 7. Report (always)
Target + contract summary + pairing actually used (models per role, fallbacks/switches, uncorrelation level achieved). Verdict matrix: criteria × iterations. Final evaluation verbatim (per-criterion verdict + reasoning). Outcome: passed at iteration K / cap reached / stalled / rubric defect / generator or evaluator failure. Final ask: "Accept this, adjust criteria and re-run, or take over manually?"

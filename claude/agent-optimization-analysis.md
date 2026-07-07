# Agent optimization analysis

Cost/savings analysis of cheap pre-passes in front of our most expensive agents. Figures are modeled estimates (assumed token volumes + scenario weights), not measured — validate before relying on them. "Expected" = probability-weighted average across likely scenarios, not a midpoint.

## Implementation: pre-spawn workflow

Pre-passes are implemented as a caller-side instruction in the agent description + a fallback in the agent body. No scripts — native tools only (Grep, Glob, Bash, llm, explorer).

The CLAUDE.md rule is generic: "If an agent description contains 'Pre-pass:', execute the instruction before spawning. Include results under [Pre-pass:] in the spawn prompt. Cache across loops; re-run after code changes."

Each agent body has a fallback: "Pre-pass results should be under [Pre-pass:] in the prompt. Start from them — do not re-discover. If the marker is missing, use {tool} yourself before reasoning."

Key design rules:
- No scripts — native tools only
- No judgment delegation — pre-passes are pure mechanical discovery
- Language-agnostic floor — grep always works
- Language-specific ceiling — Glob for config files + additional grep if detected. Union of both passes
- llm is advisory-only — per local-llm skill rules

## Expensive agents

| Tier | Agents | Why |
|---|---|---|
| Priciest (opus, xhigh) | auditor-deep, debugger-deep, planner-deep | Top rate + highest-effort reasoning |
| Expensive (opus, high) | auditor, implementer-deep, analyzer-deep, researcher-deep, planner, writer-deep | Top rate, high effort |
| Frequent (sonnet, xhigh) | reviewer | Not opus-priced, but xhigh on every call + highest call volume in the fleet |

## Per-agent analysis

### reviewer

- Issue: pays xhigh effort on every invocation regardless of diff size.
- Fix: effort gate — caller checks diff size + path sensitivity before spawning. Small/routine + non-sensitive paths → reviewer-quick (sonnet, medium). Otherwise → reviewer (sonnet, xhigh).
- Pre-pass cost: $0 (no model call, pure routing decision).
- reviewer-quick effort raised from low to medium to avoid too large a quality gap from xhigh.
- Weighting: ~65% of real diffs are small/routine.

| Best | Expected | Worst |
|---|---|---|
| 30% savings | ~20% blended | $0 (quality risk — mitigated by sensitive-path deny list) |

**Verdict: valid.** Best ROI. Sensitive paths (auth, crypto, payment, secrets, infra) never downgraded.

### implementer / implementer-deep

- Issue: finding every call site to change burns reasoning on search, not logic.
- Fix: caller greps target symbol across codebase before spawning.
- Pre-pass cost: $0 (grep / rg).

| Best | Expected | Worst |
|---|---|---|
| 45% (deep) / 20% (standard) | 25% (deep) / 12% (standard) | 0% (breakeven) |

**Verdict: valid.** Free, worst case is breakeven. Risk is false positives from substring matches — agent filters them at negligible cost.

### analyzer-deep

- Issue: builds dependency/call map by reading serially.
- Fix: caller greps import/include/require/use patterns + detects language.
- Pre-pass cost: $0 (grep + glob).
- Bimodal: static-import-heavy stacks near best case, DI/runtime-wiring stacks near worst case.

| Best | Expected | Worst |
|---|---|---|
| 52% | 22% (bimodal) | ~0% (breakeven) |

**Verdict: valid.** Strongest overall $0 optimization. Expect less on DI-heavy stacks.

### debugger / debugger-deep

- Issue: agentic loop re-reads raw logs/stack traces/git history across many turns.
- Fix: llm-compress logs/stack traces if >200 lines.
- Pre-pass cost: $0 with Ollama; real (Haiku fallback, ~$0.06/50k-token log) without.

| Agent | With Ollama Best/Expected/Worst | Without Ollama Best/Expected/Worst |
|---|---|---|
| debugger-deep | 75% / 38% / ~0% | 69% / 30% / -5% |
| debugger | 25% / 15% / ~0% | 20% / 12% / -2% |

**Verdict: valid with Ollama** — free pre-pass, worst case is breakeven. **Conditional without** — gate on Ollama availability.

### planner / planner-deep

- Issue: opus burns reasoning tokens exploring the codebase instead of judging trade-offs.
- Fix: caller spawns explorer agent (haiku, low) to pre-brief planner.
- Pre-pass cost: real (Haiku explorer agent).

| Best | Expected | Worst |
|---|---|---|
| 39% (planner) / 45% (deep) | 22% (planner) / 28% (deep) | -15% |

Weighting: 60% typical partial trust (~25%), 25% opus fully trusts briefing (~39%), 15% distrusts and re-explores (-15%).

**Verdict: conditional.** Good expected case, but loss tail matters — only when re-exploration is unlikely.

### writer-deep

- Issue: opus explores the codebase to understand context before writing (ADRs, design docs, runbooks).
- Fix: same explorer pre-brief as planner.
- Pre-pass cost: real (Haiku explorer agent).

| Best | Expected | Worst |
|---|---|---|
| 25% | 15% | -10% |

**Verdict: conditional.** Low call frequency, but $10/shared mechanism with planner.

### auditor / auditor-deep

- Issue 1 (real bug): auditor's actual prompt didn't state it must cover general correctness/quality, not just security.
- Fix: **already done** — auditor.md body now explicitly requires both.
- Issue 2 (cost idea, explored and discarded): pre-pass grep for security-sensitive patterns. **Discarded** — anchoring bias risk. Security-hotspot grep may narrow the agent's focus, causing it to miss non-grepped patterns. Adversarial thoroughness is the auditor's job — a pre-filter works against that.
- Issue 3 (cost idea, explored and discarded): split into reviewer (full diff, general pass) + auditor (scoped to security-relevant sections). Discarded — margin too thin, flips to -41% on security-dense changes.

**Verdict: prompt fix only.** Don't build the split pipeline or a security-grep pre-pass.

### researcher-deep

- Issue: fetches and reads every source itself before verifying.
- Fix: cheap parallel fetchers extract claims + source URLs first; researcher-deep only verifies/synthesizes.
- Pre-pass cost: real (Haiku fetchers).

| Best | Expected | Worst |
|---|---|---|
| 30% | 4% | -12% |

**Verdict: discarded.** Weakest case — verification work doesn't compress, pre-pass cost erases gains in expectation.

## General pattern

1. Orienting is deterministic (graphs, profiling, log-grepping, diff size) → plain grep/glob, $0, no LLM.
2. Orienting needs light exploration (explore unfamiliar codebase) → cheap explorer subagent, haiku only, conservative.
3. Never delegate actual judgment (bugs, risk, correctness) to a pre-pass — expensive agent still has to re-verify, so cost duplicates instead of dropping.

## Implementation order

| Step | What | Changes |
|---|---|---|
| 1 | CLAUDE.md — add Pre-spawn workflow + Effort gating | 2 sections |
| 2 | reviewer-quick.md — effort low → medium | 1 frontmatter edit |
| 3 | reviewer.md — routing hint in description | 1 description edit |
| 4 | implementer.md + implementer-deep.md | Description + body |
| 5 | analyzer-deep.md | Description + body |
| 6 | debugger.md + debugger-deep.md | Description + body |
| 7 | planner.md + planner-deep.md | Description + body |
| 8 | writer-deep.md | Description + body |
| 9 | agents-reference.md | Regenerate from frontmatter |
| 10 | agent-optimization-analysis.md | This document |

## Build order (priority)

| Optimization | Cost | Expected | Worst | Priority |
|---|---|---|---|---|
| Reviewer effort gate | $0 | ~20% | $0, quality risk only | Build first |
| Debugger-deep triage (w/ Ollama) | $0 | ~38% | Breakeven | Build first |
| Implementer-deep call-site | $0 | ~25% | Breakeven | Build first |
| Analyzer-deep dep graph | $0 | ~22% | Breakeven | Build first |
| Implementer call-site | $0 | ~12% | Breakeven | Build first |
| Debugger triage (w/ Ollama) | $0 | ~15% | Breakeven | Build first |
| Planner context | Real (haiku) | ~22% | -15% | Conditional — skip on unfamiliar code |
| Planner-deep context | Real (haiku) | ~28% | -15% | Conditional — skip on unfamiliar code |
| Writer-deep context | Real (haiku) | ~15% | -10% | Conditional — skip on unfamiliar code |
| Debugger-deep triage (w/o Ollama) | ~$0.06/50k | ~30% | -5% | Conditional on Ollama |
| Debugger triage (w/o Ollama) | ~$0.06/50k | ~12% | -2% | Conditional on Ollama |
| Auditor split pipeline | None | ~9% | -41% | Discarded |
| Researcher-deep pre-fetch | Real (haiku) | ~4% | -12% | Discarded |

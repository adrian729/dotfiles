# Agents reference

Reference table for the custom agents in `.claude/agents/`. Generated from each agent's frontmatter (`model`, `effort`) and `description` field — the "used for" / "not used for" columns are the actual trigger text Claude routes on, not guesses. Regenerate by re-reading `.claude/agents/*.md` if agents change.

## Task agents

| Agent | Model | Effort | Used for (triggers) | Routed elsewhere for |
|---|---|---|---|---|
| `analyzer` | sonnet | medium | Understand/investigate code proactively: "figure out how something works", trace behavior, data/control flow, "what happens when X", walk through code | Small-scope questions → `analyzer-quick`; architecture/impact analysis → `analyzer-deep`; investigating errors/failures → `debugger` |
| `analyzer-quick` | sonnet | low | Quick, small-scope questions about how code works — "what does X do" | Full behavior tracing → `analyzer`; architecture/impact analysis → `analyzer-deep` |
| `analyzer-deep` | opus | high | Thorough code analysis — cover everything analyzer does AND additionally architecture mapping, dependency maps, impact/blast-radius assessment, complex cross-cutting analysis, or explicitly thorough analysis. Pre-pass: grep import/include/require/use patterns + detect lang. | Routine behavior tracing → `analyzer` |
| `auditor` | opus | high | Audit and review code — cover everything reviewer does AND additionally focus on security, vulnerabilities/CVEs, dependencies, licenses, compliance, hardening/vetting code, and large/risky changes | Everyday reviews → `reviewer`; most safety-critical or explicitly maximum rigor → `auditor-deep` |
| `auditor-deep` | opus | xhigh | Most safety-critical/high-stakes audits — auth/crypto/payment/secret-handling paths, pre-release security sign-off — or explicitly maximum/exhaustive rigor ("leave no stone unturned") | Routine audits → `auditor` |
| `cleaner` | haiku | low | Proactive mechanical code cleanup — lint fixes, formatting, dead-code removal, import sorting, renames | Refactoring or changes requiring judgment → `implementer` |
| `debugger` | sonnet | high | Proactive debug/diagnose/troubleshoot: "why is X failing/broken/not working", reproduce failures, investigate errors/crashes, find root causes. Pre-pass: llm-compress logs/stack traces if >200 lines. | Trivially shallow failures → `debugger-quick`; gnarly/intermittent/high-stakes failures → `debugger-deep`; fixing the bug once found → `implementer` |
| `debugger-quick` | sonnet | medium | Simple, likely-shallow failures with an obvious reproduction — "obvious error", quick look at a failure. Pre-pass: (inherits from debugger if escalated). | Real root-cause investigations → `debugger`; gnarly/intermittent failures → `debugger-deep` |
| `debugger-deep` | opus | xhigh | Thorough debugging — cover everything debugger does AND additionally gnarly, intermittent, or high-stakes failures (flaky tests, race conditions, only happens sometimes/in prod) or when prior debugging failed. Pre-pass: llm-compress logs/stack traces if >200 lines. | Routine debugging → `debugger` |
| `explorer` | haiku | low | Proactive codebase exploration: find/locate/search files, symbols, definitions, usages ("where is X?", "show me X", "do we have/is there a"), read known files, list/inventory things | Tracing behavior → `analyzer`; condensing content → `summarizer`; exhaustive sweeps → `explorer-deep` |
| `explorer-deep` | sonnet | medium | Thorough or exhaustive exploration — "find all/every place", "all callers", "make sure nothing is missed" across many locations/naming conventions, or when a quick lookup missed things | Simple lookups → `explorer` |
| `implementer` | sonnet | medium | Proactive implement/add/build/create features, change/update code, fix bugs, write tests, refactor, prototype/spike, port/translate code. Pre-pass: Grep target symbol across codebase. | Boilerplate → `implementer-quick`; migrations/optimization/risky cross-cutting changes → `implementer-deep`; lint/format cleanup → `cleaner` |
| `implementer-quick` | sonnet | low | Scaffolding, boilerplate, stubs/skeletons, small self-contained code edits or tweaks | Features/fixes/tests → `implementer`; migrations or risky changes → `implementer-deep` |
| `implementer-deep` | opus | high | Thorough implementation — cover everything implementer does AND additionally framework migrations/major upgrades, rewrites, performance optimization ("make it faster", "too slow"), and cross-cutting or risky code changes. Pre-pass: Grep target symbol across codebase. | Routine coding → `implementer` |
| `operator` | sonnet | medium | Proactive install/set up/configure environment, CI, tooling, docker, pipelines — "get X working locally" — and batch data processing | Just running/watching things → `operator-quick`; diagnosing failures → `debugger`; deploys/releases (user-gated, never delegated) |
| `operator-quick` | sonnet | low | Run/kick off builds, tests, or scripts; monitor/watch/poll long-running jobs or CI ("is CI green", "check pipeline status") | Environment/CI/tooling setup or data processing → `operator`; diagnosing failures → `debugger` |
| `planner` | opus | high | Proactive implementation plans ("plan out X", "how should we approach"), API/schema/component design, proposals, trade-off analysis ("which option", "pros and cons"). Pre-pass: explore codebase structure with explorer agent. | Specs/estimates → `planner-quick`; high-stakes architecture → `planner-deep` |
| `planner-quick` | sonnet | medium | Writing specs, tickets/user stories, acceptance criteria, effort estimates ("how long would X take") | Implementation plans or design → `planner` |
| `planner-deep` | opus | xhigh | Thorough planning — cover everything planner does AND additionally large or high-stakes architecture/design decisions (rearchitecting, RFCs) or explicitly maximum planning rigor. Pre-pass: explore codebase structure with explorer agent. | Everyday plans → `planner` |
| `researcher` | sonnet | medium | Proactive research/look up/search the web or docs — best practices, library comparisons, "current/latest way to do X", error lookups | Fetching a specific known resource → `researcher-quick`; multi-source verified research → `researcher-deep` |
| `researcher-quick` | sonnet | low | Fetch/get specific external resources — tickets, PRs, issues, a given URL, a known docs page, "what does this ticket/PR say" | Open-ended research → `researcher` |
| `researcher-deep` | opus | high | Thorough research — cover everything researcher does AND additionally deep multi-source verified research (deep dive, verify claims, cite sources) or explicitly thorough research | Routine lookups → `researcher` |
| `reviewer` | sonnet | xhigh | Proactive code review — "check/look over my changes", "does this look right", feedback on X — verifying a change works, critiquing/judging alternatives. For small/routine diffs not on sensitive paths, consider reviewer-quick first. | Quick sanity checks or triage → `reviewer-quick`; audits/security/large or risky changes or explicit thoroughness → `auditor` |
| `reviewer-quick` | sonnet | medium | Quick review or sanity/gut check on small diffs ("quick look", "is this fine"), or triage/classify issues and failures. Small diffs on non-sensitive paths → preferred over reviewer. | Standard code review → `reviewer`; audits or risky changes → `auditor` |
| `summarizer` | sonnet | medium | Proactive summarize/condense/recap/TL;DR of files, diffs, logs, transcripts — "what changed", "catch me up", key points | Quick gists → `summarizer-quick`; long/nuanced material where missing detail matters → `summarizer-deep`; huge raw logs/diffs where the gist suffices → `local-llm` skill |
| `summarizer-quick` | sonnet | low | Quick or rough summary/gist/skim of a file, diff, log, or transcript ("roughly what is in X") | Standard summaries → `summarizer`; huge raw logs/diffs where gist suffices → `local-llm` skill |
| `summarizer-deep` | sonnet | high | Long, dense, or high-stakes material where missing detail matters ("do not miss anything", "every detail"), or explicitly thorough summaries | Everyday summaries → `summarizer` |
| `writer` | sonnet | medium | Proactive write/write up/document — READMEs, reports, diagrams (draw, mermaid), charts, dashboards, visualizations | Short routine text → `writer-quick`; ADRs or high-stakes documents → `writer-deep` |
| `writer-quick` | sonnet | low | PR descriptions, commit messages, changelogs, release notes, short routine text | READMEs/reports/diagrams → `writer`; ADRs or high-stakes documents → `writer-deep` |
| `writer-deep` | opus | medium | ADRs, design docs, proposals, runbooks, postmortems, onboarding guides, documents where quality and completeness matter most. Pre-pass: explore codebase structure with explorer agent. | Everyday docs → `writer` |

## Effort carriers

These have no fixed `model` — they inherit whatever model the caller passes at spawn time (per this repo's routing convention) and only exist to force a specific reasoning effort.

| Agent | Effort | Used for (triggers) |
|---|---|---|
| `effort-low` | low | User explicitly asks "low"/"minimal"/"cheap" effort for a delegated task |
| `effort-medium` | medium | User explicitly asks "medium"/"normal"/"standard" effort for a delegated task |
| `effort-high` | high | User explicitly asks "high" effort for a delegated task (not "very/extra high") |
| `effort-xhigh` | xhigh | User explicitly asks "xhigh"/"very high"/"extra high" effort for a delegated task |
| `effort-max` | max | User explicitly asks "max"/"maximum" effort for a delegated task |

## Model capabilities — when to use each

Independent, first-principles reference for the four models this fleet routes across, sourced from the `claude-api` skill's model catalog and per-model docs (not from the agent assignments above). Use it as the yardstick when auditing whether each agent's `model`/`effort` pairing fits its job.

| Model | Cost (in/out per MTok) | Context | Max out | Effort | Positioning (task-fit) | When to use | Don't use when |
|---|---|---|---|---|---|---|---|
| Haiku 4.5 | $1 / $5 | 200K | 64K | none | Fastest, cheapest; for simple, speed-critical tasks | Mechanical, high-volume, latency-bound: classification, extraction, formatting, lint fixes, simple lookups, quick sanity checks, cheap batch | Any real multi-step reasoning; you need an effort dial; context >200K |
| Sonnet 5 | $3 / $15 ($2/$10 intro→2026-08-31) | 1M | 128K | low→max | Best speed/intelligence balance; near-Opus on coding and agentic work | Default workhorse: everyday coding, features, tests, standard review, routine debugging, agentic/tool loops, summarization, research, most writing. Push effort to `xhigh` before bumping tier | Task is trivially mechanical (→ Haiku) or genuinely frontier-hard (→ Opus/Fable) |
| Opus 4.8 | $5 / $25 | 1M | 128K | low→max | Most capable Opus-tier; SOTA long-horizon agentic, knowledge work, and memory | Correctness-critical & long-horizon: autonomous agentic runs, big refactors, architecture/impact analysis, gnarly/intermittent debugging, self-verifying knowledge work, memory-heavy tasks, high-stakes docs/reviews. Give full task spec up front at `high`/`xhigh` | Routine work Sonnet 5 handles cheaper; latency-sensitive interactive use |
| Fable 5 | $10 / $50 | 1M | 128K | low→max (thinking always on) | Most capable widely released model; for the most demanding reasoning and long-horizon agentic work | Frontier-difficulty only: novel/unsolved problems, longest-horizon autonomous runs, sustained multi-agent orchestration, exhaustive audits/deep research where "leave nothing out" is the real requirement | Anything latency-sensitive (turns run minutes); security/cyber-adjacent work (classifiers false-positive); tasks Opus already handles (pure 2× waste) |

Two cross-cutting rules the rows assume:
- **Effort before tier** — Sonnet 5 at `xhigh` ≈ Opus at `medium` on much coding/agentic work; raise the effort dial before jumping model tier.
- **Difficulty ≠ stakes for the top two** — critical-but-tractable is an Opus job; Fable is only for problems at or beyond Opus's ceiling.

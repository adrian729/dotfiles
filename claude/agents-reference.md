# Agents reference

Inventory of `.claude/agents/`, generated from the frontmatter. The definitions are authoritative; refresh this table when their names, descriptions, models, or efforts change.

## Task agents

| Agent | Model | Effort | Description |
| --- | --- | --- | --- |
| `analyzer-deep` | opus | high | Use for thorough code analysis — cover everything analyzer does AND additionally architecture mapping, dependency maps, impact/blast-radius assessment, complex cross-cutting analysis, or explicitly thorough analysis. NOT: routine behavior tracing (analyzer). |
| `analyzer-quick` | sonnet | low | Use to quickly answer small-scope questions about how code works — what does X do, quick question about behavior. NOT: full behavior tracing (analyzer), architecture/impact analysis (analyzer-deep). |
| `analyzer` | sonnet | medium | Use PROACTIVELY to analyze or understand code — investigate/look into/figure out how something works, trace behavior, data/control flow, what happens when X, walk through code. NOT: small-scope questions (analyzer-quick), architecture/impact analysis (analyzer-deep), investigating errors/failures (debugger). |
| `auditor-deep` | opus | xhigh | Use for the most safety-critical or high-stakes audits — cover everything auditor does AND additionally auth/crypto/payment/secret-handling paths, pre-release security sign-off, or explicitly maximum or exhaustive rigor (leave no stone unturned). NOT: routine audits (auditor). |
| `auditor` | opus | high | Use PROACTIVELY to audit and review work — cover everything reviewer does AND additionally focus on security, vulnerabilities/CVEs, dependencies, licenses, compliance, hardening, and large/risky changes. NOT: everyday reviews (reviewer), most safety-critical or explicitly maximum rigor (auditor-deep). |
| `cleaner` | haiku | low | Use PROACTIVELY for mechanical code cleanup — lint fixes, formatting, dead-code removal, import sorting, renames. NOT: refactoring or changes requiring judgment (implementer). |
| `debugger-deep` | opus | xhigh | Use for thorough debugging — cover everything debugger does AND additionally gnarly, intermittent, or high-stakes failures (flaky tests, race conditions, only happens sometimes/in prod) or when prior debugging failed. NOT: routine debugging (debugger). |
| `debugger-quick` | sonnet | medium | Use to debug simple, likely-shallow failures with an obvious reproduction — obvious error, quick look at a failure. NOT: real root-cause investigations (debugger), gnarly/intermittent failures (debugger-deep). |
| `debugger` | sonnet | high | Use PROACTIVELY to debug, diagnose, or troubleshoot — why is X failing/broken/not working, reproduce failures, investigate/look into errors/crashes, find root causes. NOT: trivially shallow failures (debugger-quick), gnarly/intermittent/high-stakes failures (debugger-deep), fixing bug once found (implementer). |
| `explorer-deep` | sonnet | medium | Use for thorough or exhaustive codebase exploration — find all/every place/all callers, make sure nothing is missed — across many locations or naming conventions, or when a quick lookup missed things. NOT: simple lookups (explorer). |
| `explorer` | haiku | low | Use PROACTIVELY to explore a codebase — find/locate/search files, symbols, definitions, or usages (where is X? show me X, do we have/is there a, which file), read known files, or list/inventory things. NOT: tracing behavior (analyzer), condensing content (summarizer), exhaustive sweeps (explorer-deep). |
| `implementer-deep` | opus | high | Use for thorough implementation — cover everything implementer does AND additionally framework migrations/major upgrades, rewrites, performance optimization (make it faster, too slow), and cross-cutting or risky code changes. NOT: routine coding (implementer). |
| `implementer-quick` | sonnet | low | Use for scaffolding, boilerplate, stubs/skeletons, and small self-contained code edits or tweaks. NOT: features/fixes/tests (implementer), migrations or risky changes (implementer-deep), mechanical cleanup (cleaner). |
| `implementer` | sonnet | medium | Use PROACTIVELY to implement/add/build/create features, change/update code, fix bugs, write tests, refactor, prototype/spike, or port/translate code. NOT: boilerplate (implementer-quick), migrations/optimization/risky cross-cutting changes (implementer-deep), lint/format cleanup (cleaner). |
| `operator-quick` | sonnet | low | Use to run/kick off builds, tests, or scripts, and to monitor/watch/poll long-running jobs or CI (is CI green, check pipeline status). NOT: environment/CI/tooling setup or data processing (operator), diagnosing failures (debugger). |
| `operator` | sonnet | medium | Use PROACTIVELY to install/set up/configure environment, CI, tooling, docker, pipelines — get X working locally — and batch data processing. NOT: just running or watching things (operator-quick), diagnosing failures (debugger). |
| `planner-deep` | opus | xhigh | Use for thorough planning — cover everything planner does AND additionally large or high-stakes architecture/design decisions (rearchitecting, RFCs) or explicitly maximum planning rigor. NOT: everyday plans (planner). |
| `planner-quick` | sonnet | medium | Use for writing specs, tickets/user stories, acceptance criteria, or effort estimates (how long would X take). NOT: implementation plans or design (planner). |
| `planner` | opus | high | Use PROACTIVELY for implementation plans (plan out X, how should we approach), API/schema/component design, proposals, and trade-off analysis (which option, pros and cons). NOT: specs/estimates (planner-quick), high-stakes architecture (planner-deep). |
| `researcher-deep` | opus | high | Use for thorough research — cover everything researcher does AND additionally deep multi-source verified research (deep dive, verify claims, cite sources) or explicitly thorough research. NOT: routine lookups (researcher). |
| `researcher-quick` | sonnet | low | Use to fetch/get specific external resources — tickets, PRs, issues, given URL, known docs page, what does this ticket/PR say. NOT: open-ended research (researcher). |
| `researcher` | sonnet | medium | Use PROACTIVELY to research, look up, or search the web/docs — best practices, library comparisons/which library to use, current/latest way to do X, error lookups. NOT: fetching specific known resource (researcher-quick), multi-source verified research (researcher-deep). |
| `reviewer-quick` | sonnet | medium | Use for quick review or sanity/gut check on small work or diffs ("quick look", "is this fine"), or to triage/classify issues and failures. NOT: standard review (reviewer), audits or risky changes (auditor). |
| `reviewer` | sonnet | xhigh | Use PROACTIVELY to review work — check/look over changes, plans, docs; does this look right; feedback on X; verifying something works; critiquing/judging alternatives. NOT: quick sanity checks or triage (reviewer-quick), audits/security/large or risky changes or explicit thoroughness (auditor). For small/routine code diffs not on sensitive paths, consider reviewer-quick first. |
| `summarizer-deep` | sonnet | high | Use to summarize long, dense, or high-stakes material where missing detail matters (do not miss anything, every detail), or explicitly thorough summaries. NOT: everyday summaries (summarizer). |
| `summarizer-quick` | sonnet | low | Use for quick or rough summary/gist/skim of a file, diff, log, or transcript (roughly what is in X). NOT: standard summaries (summarizer), huge raw logs/diffs where gist suffices (local-llm skill). |
| `summarizer` | sonnet | medium | Use PROACTIVELY to summarize, condense, recap, or TL;DR files, diffs, logs, or transcripts — what changed, catch me up, key points. NOT: quick gists (summarizer-quick), long/nuanced material where missing detail matters (summarizer-deep), huge raw logs/diffs where gist suffices (local-llm skill). |
| `writer-deep` | opus | medium | Use for ADRs, design docs, proposals, runbooks, postmortems, onboarding guides, and documents where quality and completeness matter most. NOT: everyday docs (writer). |
| `writer-quick` | sonnet | low | Use for PR descriptions, commit messages, changelogs, release notes, and short routine text. NOT: READMEs/reports/diagrams (writer), ADRs or high-stakes documents (writer-deep). |
| `writer` | sonnet | medium | Use PROACTIVELY to write, write up, or document — READMEs, reports, diagrams (draw, mermaid), charts, dashboards, visualizations. NOT: short routine text (writer-quick), ADRs or high-stakes documents (writer-deep). |

## OpenCode delegation wrappers

These preload the `opencode-task` skill and run their named OpenCode agent directly with an explicit model. The Haiku model belongs to the Claude dispatcher; the OpenCode model is selected separately. Worktrees separate checkouts but do not confine tool access. Preserve the worktree until its result is reviewed and integrated.

| Agent | Model | Effort | Description |
| --- | --- | --- | --- |
| `opencode-auditor` | haiku | low | Delegate a security or sensitive-path audit to OpenCode in a separate worktree. |
| `opencode-debugger` | haiku | low | Delegate failure reproduction and root-cause investigation to OpenCode in a separate worktree. |
| `opencode-general` | haiku | low | Delegate independent work to OpenCode in a separate worktree when no specialist fits. |
| `opencode-implementer-quick` | haiku | low | Delegate small self-contained edits, stubs, or scaffolding to OpenCode in a separate worktree. |
| `opencode-implementer` | haiku | low | Delegate features, fixes, tests, or refactoring to OpenCode in a separate worktree. |
| `opencode-planner` | haiku | low | Delegate implementation planning and design trade-offs to OpenCode in a separate worktree. |
| `opencode-researcher` | haiku | low | Delegate documentation lookup and technical research to OpenCode in a separate worktree. |
| `opencode-reviewer-quick` | haiku | low | Delegate a quick sanity check or triage of a small diff to OpenCode in a separate worktree. |
| `opencode-reviewer` | haiku | low | Delegate code review to OpenCode in a separate worktree; use opencode-auditor for security audits. |

## Effort carriers

These leave the model unpinned so callers can combine an explicit model choice with an effort setting supported by that model.

| Agent | Model | Effort | Description |
| --- | --- | --- | --- |
| `effort-high` | inherit | high | Use when user explicitly asks "high" effort for delegated task (not "very/extra high" — that's effort-xhigh). |
| `effort-low` | inherit | low | Use when user explicitly asks "low"/"minimal"/"cheap" effort for delegated task. |
| `effort-max` | inherit | max | Use when user explicitly asks "max"/"maximum" effort for delegated task. |
| `effort-medium` | inherit | medium | Use when user explicitly asks "medium"/"normal"/"standard" effort for delegated task. |
| `effort-xhigh` | inherit | xhigh | Use when user explicitly asks "xhigh"/"very high"/"extra high" effort for delegated task. |

## Model and effort support

Model aliases and available effort levels depend on the installed Claude Code version and account. Consult the current [model configuration](https://code.claude.com/docs/en/model-config) and [subagent documentation](https://code.claude.com/docs/en/sub-agents) when changing assignments. This table records configured choices; it is not a benchmark, price catalog, or guarantee that every model honors every effort level.

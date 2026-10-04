# Agents reference

Inventory of `.claude/agents/`, generated from the frontmatter. The definitions are authoritative; refresh this table when their names, descriptions, models, or efforts change.

## Task agents

| Agent | Model | Effort | Description |
| --- | --- | --- | --- |
| `analyzer-deep` | opus | high | Analyze architecture, dependencies, and the impact of cross-cutting changes. |
| `analyzer-quick` | sonnet | low | Answer a narrow question about how a piece of code works. |
| `analyzer` | sonnet | medium | Explain code behavior, control flow, and data flow. |
| `auditor-deep` | opus | xhigh | Investigate sensitive paths and high-stakes security or correctness risks in depth. |
| `auditor` | opus | high | Audit correctness and security, including dependencies and identified compliance requirements. |
| `cleaner` | haiku | low | Apply requested mechanical cleanup: formatting, imports, dead code, and straightforward renames. |
| `debugger-deep` | opus | xhigh | Investigate intermittent, cross-cutting, or high-stakes failures and unsuccessful prior fixes. |
| `debugger-quick` | sonnet | medium | Investigate a small, reproducible failure with a likely local cause. |
| `debugger` | sonnet | high | Investigate failures, identify root causes, and verify requested fixes. |
| `explorer-deep` | sonnet | medium | Trace references and discover relevant code across a large or unfamiliar codebase. |
| `explorer` | haiku | low | Locate files, symbols, definitions, and usages in a codebase. |
| `implementer-deep` | opus | high | Implement migrations, substantial rewrites, performance improvements, and cross-cutting changes. |
| `implementer-quick` | sonnet | low | Make small self-contained edits, stubs, and scaffolding. |
| `implementer` | sonnet | medium | Implement features, bug fixes, tests, and refactors. |
| `operator-quick` | sonnet | low | Run builds, tests, or scripts and monitor their results. |
| `operator` | sonnet | medium | Set up environments, tooling, CI, and pipelines; perform requested operational tasks. |
| `planner-deep` | opus | xhigh | Develop architecture and plans for complex or high-stakes changes. |
| `planner-quick` | sonnet | medium | Draft specifications, tickets, acceptance criteria, and effort estimates. |
| `planner` | opus | high | Develop implementation plans, designs, and trade-off analyses. |
| `researcher-deep` | opus | high | Research a complex question across sources and verify consequential claims. |
| `researcher-quick` | sonnet | low | Retrieve and summarize a specified external resource, ticket, or documentation page. |
| `researcher` | sonnet | medium | Research external documentation, current practices, and technical alternatives. |
| `reviewer-quick` | sonnet | medium | Check a small change for clear problems or triage reported issues. |
| `reviewer` | sonnet | xhigh | Review code, plans, or documentation for actionable correctness and quality issues. |
| `summarizer-deep` | sonnet | high | Summarize dense or consequential material with particular care for qualifications and evidence. |
| `summarizer-quick` | sonnet | low | Produce a brief gist of supplied material. |
| `summarizer` | sonnet | medium | Summarize files, diffs, logs, or transcripts while preserving relevant details. |
| `writer-deep` | opus | medium | Write substantial design documents, proposals, runbooks, and postmortems. |
| `writer-quick` | sonnet | low | Write short routine text, including PR descriptions, commit messages, and release notes. |
| `writer` | sonnet | medium | Write documentation, reports, diagrams, and explanations. |

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

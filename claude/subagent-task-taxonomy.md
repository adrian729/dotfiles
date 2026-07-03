# Subagent Task Taxonomy & Control Plan

## Goal

Claude Code spawns subagents (Explore, Plan, general-purpose, custom `.claude/agents/*.md`) on its own judgment. We want control over **which model and effort** each delegated task runs with, depending on task type, situation, and user request — enforced, without steering every prompt. Concretely:

1. **Automatic tiering**: each task type gets a sensible model/effort by default (e.g. deep review → strong model, high effort; quick lookup → cheap model, low effort).
2. **Manual control on demand**: saying "use Opus with xhigh effort" must work for any model × any effort combination.
3. **Enforcement**: the pinned model/effort should hold, not depend on Claude remembering instructions.

## Task families

### 1. Information gathering — codebase (read-only)

| Task | What it is |
|---|---|
| **Explore / locate** | Find files, symbols, definitions, usages ("where is X?") |
| **Understand / analyze** | Trace behavior, map architecture, follow data/control flow, explain how something works |
| **Read** | Ingest specific known files/artifacts and extract facts |
| **Summarize** | Condense a file, diff, log, or transcript into a digest |
| **Inventory / catalog** | Enumerate things: endpoints, dependencies, TODOs, feature flags, config keys |

### 2. Information gathering — external

| Task | What it is |
|---|---|
| **Research (web)** | Docs, best practices, library comparisons, error-message lookups |
| **Fetch external resources** | Read tickets, PRs, issues, API docs, wikis (GitHub, Jira, Notion…) |
| **Deep research** | Multi-source, verified, synthesized report on a topic |

### 3. Evaluation / judgment (read-only)

| Task | What it is |
|---|---|
| **Review** | Code review of a diff/PR: correctness, style, simplification |
| **Audit** | Broader sweep against a rubric: security, accessibility, licenses, dependencies, dead code |
| **Verify / validate** | Confirm a change actually works: run it, reproduce, exercise the flow end-to-end |
| **Critique / judge** | Score or refute alternatives, adversarial verification of a finding/claim |
| **Impact assessment** | Blast radius of a proposed change; what breaks if X changes |
| **Triage** | Classify and prioritize issues, failures, findings |

### 4. Design / planning

| Task | What it is |
|---|---|
| **Plan** | Step-by-step implementation plan for a task |
| **Design / architect** | API design, schema design, component structure, trade-off analysis |
| **Specify** | Requirements, acceptance criteria, interface contracts |
| **Estimate** | Effort/complexity sizing |

### 5. Creation — code (mutating)

| Task | What it is |
|---|---|
| **Implement** | New feature or functionality |
| **Fix** | Bug fix (given a known cause) |
| **Refactor** | Restructure without behavior change |
| **Migrate / upgrade** | Dependency bumps, API migrations, codemods, framework moves |
| **Optimize** | Performance / memory / bundle-size improvements |
| **Scaffold / generate** | Boilerplate, new module/project skeletons, config generation |
| **Write tests** | Unit / integration / e2e test authoring |
| **Prototype / spike** | Throwaway exploratory code to answer a question |
| **Translate / port** | Between languages, frameworks, or formats; i18n |
| **Cleanup** | Lint fixes, formatting, dead-code removal, import sorting |

### 6. Creation — non-code (mutating)

| Task | What it is |
|---|---|
| **Document** | README, docstrings, changelogs, ADRs, onboarding guides |
| **Write content** | Reports, emails, PR descriptions, blog posts |
| **Visualize** | Diagrams, charts, dashboards, HTML artifacts |

### 7. Operations / execution

| Task | What it is |
|---|---|
| **Run / execute** | Builds, test suites, scripts, one-off commands |
| **Debug / diagnose** | Reproduce a failure and root-cause it (investigation, distinct from fixing) |
| **Configure / setup** | Environment, tooling, CI, settings, hooks, MCP servers |
| **Deploy / release** | Publish, tag, release notes, version bumps |
| **Monitor / watch** | Poll CI runs, long-running jobs, deployments |
| **Data processing** | ETL, batch transforms, file conversions, scraping |

### 8. Repo / workflow management

| Task | What it is |
|---|---|
| **Git operations** | Commit, branch, rebase, merge, worktrees, PR creation |
| **Issue/PR management** | Open, label, comment, link, close via `gh`/MCP |

### 9. Meta / orchestration

| Task | What it is |
|---|---|
| **Decompose / orchestrate** | Split a big task into subtasks and coordinate agents |
| **Synthesize / merge** | Combine results from multiple agents into one answer |
| **Explain / teach** | Answer a question directly (no artifact produced) |
| **Clarify** | Ask the user for missing decisions (never delegable) |

## Cross-cutting control dimensions

When mapping tasks to spawn policies, these axes matter as much as the task type:

- **Read-only vs. mutating** — read-only tasks are safe to fan out in parallel; mutating ones need isolation (worktree) or serialization
- **Internal vs. external** — codebase-only vs. touches web/APIs/third-party services
- **Reversible vs. irreversible** — deploys, pushes, deletions need gates
- **Parallelizable vs. sequential** — independent items vs. dependent steps
- **Effort tier** — mechanical (cheap model, low effort) vs. judgment-heavy (strong model, high effort)

## Verified facts & constraints

Verified against the official Claude Code docs (sub-agents.md, hooks-guide.md, effort docs).

- **Routing**: every custom agent's `name` + `description` is in Claude's context at spawn time; the `description` frontmatter is the **only** routing signal. On "spawn subagents to do X", Claude matches the task against descriptions automatically. Routing is **advisory** — sharp trigger-style descriptions get ~80–90% reliability, never 100%.
- **Model**: the Agent tool has a call-time `model` param that **overrides** frontmatter — frontmatter model is a default, not a limit.
- **Effort**: there is **no** call-time effort param. Effort comes only from the session setting or agent frontmatter → frontmatter effort is airtight with zero hooks. Levels: `low`, `medium`, `high`, `xhigh`, `max`. `max` is not plan-restricted (works on subscription); settings docs list only up to `xhigh` for the session-wide knob, so verify `max` once with a real spawn.
- **Hooks**: cannot redirect a spawn — PreToolUse can only allow or block (exit 2 + stderr fed back to Claude, which retries; block-and-retry, one cancelled call per trigger). UserPromptSubmit is the only hook that fires **before** the delegation decision.
- **CLAUDE.md**: no documented routing effect → not used for this.

## Design

Four building blocks, in priority order:

### A. Effort-carrier agents — manual model × effort (goal 2)

One dummy agent per effort level with ONLY `effort` pinned — no `model` in frontmatter, so the agent inherits the session model or accepts any call-time `model` param, while effort is unoverridable. "Spawn a subagent on Opus with xhigh" → `Agent(subagent_type: "effort-xhigh", model: "opus")` → Opus + xhigh.

File pattern (body is irrelevant boilerplate — it's the subagent's system prompt; the config is all frontmatter):

```markdown
---
name: effort-xhigh
description: Use when the user explicitly asks for "xhigh", "very high", or "extra high" effort for a delegated task.
effort: xhigh
---
Complete task
```

Descriptions per level — single sentence, keyword-gated with a closed synonym list, neighbors fenced where they could collide (vibes like "be thorough" must NOT match; those belong to the family variants):

- `effort-low`: Use when the user explicitly asks for "low", "minimal", or "cheap" effort for a delegated task.
- `effort-medium`: Use when the user explicitly asks for "medium", "normal", or "standard" effort for a delegated task.
- `effort-high`: Use when the user explicitly asks for "high" effort for a delegated task (not "very/extra high" — that's effort-xhigh).
- `effort-xhigh`: Use when the user explicitly asks for "xhigh", "very high", or "extra high" effort for a delegated task.
- `effort-max`: Use when the user explicitly asks for "max" or "maximum" effort for a delegated task.

### B. Task-family variant agents — automatic tiering (goal 1)

Skinny files (description + model + effort, nothing else). Each role gets up to three variants: quick / *(no modifier)* / deep. Rules:

- **Every agent pins a model** — no inheriting. If the user explicitly names a model, family agents must NOT fire; that routes to the effort carriers (`effort-*` + call-time `model` param). Each description carries this fence.
- Deep = one step up in model and effort; quick = one step down. No variant where the base is already at the floor (haiku/low), where the step-down would put nuanced work on haiku (summaries, prose), or where the "variant" is really another role's job.
- `max` effort is reserved for the carriers — no family agent uses it.
- Haiku only where work is mechanical and mistakes are cheap/obvious; sonnet is the workhorse; opus for bounded deep reasoning; fable where judgment quality compounds (final review, planning, nasty bugs).

The matrix (model · effort):

| Role | What it's for | quick | *(no modifier)* | deep |
|---|---|---|---|---|
| `explorer` | Find files/symbols/usages, read known files, inventory things | — | haiku · low | sonnet · medium |
| `summarizer` | Condense files, diffs, logs, transcripts | sonnet · low | sonnet · medium | opus · high |
| `analyzer` | Trace behavior, map architecture; deep also owns impact assessment | sonnet · low | sonnet · medium | opus · high |
| `researcher` | quick: fetch tickets/PRs/known pages; normal: web/docs research | sonnet · low | sonnet · medium | opus · high |
| `reviewer` | Review, verify, critique; quick also owns triage; deep: audits, risky changes | sonnet · low | opus · high | fable · xhigh |
| `planner` | quick: specs, estimates; normal: plans, design; deep: high-stakes architecture | opus · medium | fable · high | fable · xhigh |
| `implementer` | quick: scaffolding; normal: features/fixes/tests/ports; deep: migrations, optimization | sonnet · low | sonnet · medium | opus · high |
| `cleaner` | Lint, formatting, dead code, mechanical renames | — | haiku · low | — |
| `writer` | quick: PR descriptions, changelogs; normal: READMEs, reports, diagrams; deep: ADRs | sonnet · low | sonnet · medium | opus · medium |
| `operator` | quick: run, monitor; normal: configure/setup, data processing | sonnet · low | sonnet · medium | — |
| `debugger` | Reproduce failures, root-cause | sonnet · medium | opus · high | fable · xhigh |

Missing-variant reasoning: `explorer`/`cleaner` no quick (floor); `cleaner` no deep (deep cleanup = refactoring → implementer); `operator` no deep (deep ops = root-causing → debugger); `writer-deep` deviates from the +1-effort rule (opus·medium, not high) — writing rewards the model step, rarely the effort step.

29 family agents + 5 effort carriers = 34 total. Families 8–9 (git/workflow, orchestration) stay with the main loop — not delegated. **Deploy/release is excluded from delegation entirely** and hard-gated by `permissions.ask` rules on deploy commands in `settings.json` (npm publish, gh release, docker push, terraform apply, kubectl apply, cargo publish) — the gate rides on the command, not the routing, so it holds even if routing fails.

**Testing the no-modifier tiers** (deep is assumed to dominate its normal; quick quality is tolerated by definition): canary tasks with known ground truth — summarizer: a file you know well, the load-bearing points must all appear; reviewer: a diff with 3 planted bugs, find ≥2 incl. one subtle, no fabrications; analyzer: a trace you can check; implementer: small feature + passing test; researcher: a docs-verifiable question; debugger: a failure whose root cause you already found. A failed canary = bump that role's frontmatter one tier (one-line fix).

### C. Routing reminder hook — reliability (goal 1)

`agent-eval.sh` (UserPromptSubmit, sibling of the existing `skill-eval.sh`): injects a one-line reminder to route matching tasks through the custom agents. The only hook point that fires before the delegation decision.

### D. PreToolUse block hook — enforcement backstop (goal 3, deferred)

Only if misrouting or unwanted model overrides are observed: block Agent calls that pass `model` (except on `effort-*` agents, where passing a model is the intended use) or that use `general-purpose` for a covered task, naming the correct agent in stderr. Until then, enforcement rests on: effort frontmatter (airtight by construction) + descriptions + the reminder hook.

## Status

- ✅ **A. Effort carriers**: five files created in `dotfiles/claude/.claude/agents/` (`effort-low|medium|high|xhigh|max.md`).
- ✅ **B. Family variants**: matrix decided (see Design B); 29 files created in `dotfiles/claude/.claude/agents/`.
- ✅ **Deploy gate**: `permissions.ask` rules for deploy commands added to `settings.json`.
- ⚠️ **Not live yet**: `~/.claude/agents` doesn't exist — stow/symlink the repo dir like hooks (`~/.claude/hooks -> ../dotfiles/claude/.claude/hooks`).
- ✅ **C. Routing hook**: `hooks/agent-eval.sh` written and registered under UserPromptSubmit; exits quietly until `~/.claude/agents` is stowed.
- ✅ **D. Block hook**: `hooks/agent-guard.sh` written and registered under PreToolUse (matcher `Agent|Task`); blocks call-time `model` params except on `effort-*` carriers, fails open without jq.

## Roadmap

1. **Stow/link agents dir** so `~/.claude/agents` points at the repo; confirm the 34 agents appear in a new session.
2. **Test effort carriers**: one spawn per level ("spawn a subagent with cheap effort to do X"), including a `model` override ("on Opus with xhigh"); explicitly verify `max` works on subscription.
3. **Run the no-modifier canaries** (see Design B testing) for the most-used roles first — summarizer and reviewer — then the rest as they come up; bump frontmatter tiers on failures.
4. ~~Write `agent-eval.sh`~~ done — verify the reminder appears in a new session once agents are stowed.
5. ~~Add the PreToolUse block hook~~ done — verify a blocked spawn self-corrects (ask for a family agent with an explicit model and watch the retry go through an effort-* carrier).

# AI Agent Usage Patterns

A reference list of ways/patterns to use AI coding agents (Claude Code and peers), current as of July 2026. Grouped by theme; each entry gives the name(s) and what it is / why you'd use it.

## Interactive single-agent workflows

- **Pair programming (interactive mode)** — The default: converse with the agent, review as it works, steer mid-task. Best signal-to-noise for exploratory or ambiguous work where human judgment is needed continuously.
- **Plan-then-execute (plan mode)** — Agent researches and produces a plan for approval before touching code. Separates cheap thinking from expensive/risky doing; catches wrong approaches early.
- **Spec-driven development** — Write a spec/PRD first (or have the agent draft one), then implement against it. The spec becomes the source of truth the agent can be held to; scales better than chat history for larger features.
- **TDD with agents** — Write (or have the agent write) failing tests first, then let the agent iterate until green. Gives the agent an objective, machine-checkable target instead of "looks done."
- **Vibe coding → agentic engineering** — Loose conversational iteration without reviewing output. Still fine for throwaway prototypes; for production work the practice (and the term, per Karpathy Feb 2026) has been superseded by "agentic engineering" — orchestrating agents with specs, verification, and review.
- **Checkpoint / rewind** — Snapshot state (git commits, harness checkpoints) so you can roll back agent mistakes cheaply. Makes aggressive delegation safe: bad runs cost a revert, not a cleanup.

## Loops and autonomy

- **Ralph (Ralph Wiggum loop)** — Geoffrey Huntley's brute-force pattern: run the same prompt in a `while` loop, fresh context each iteration, until the task is done. Trades tokens for reliability; the agent re-reads state each pass so it can't get stuck on its own stale context. Now absorbed into native primitives (`/loop`, `/goal`) and structured forks (Ralph Orchestrator with role "hats", ralph-claude-code with exit safeguards).
- **Loop engineering** — The 2026 evolution of "I write loops now": authoring autonomous, scheduled agent-prompt programs with built-in verification and guardrails, treated as a discipline distinct from ad hoc prompting.
- **Evaluator-optimizer loop** — One agent generates, another critiques, repeat until the critic passes it. One of Anthropic's canonical workflow patterns; still current and widely productized.
- **Audit loop** — Iteratively audit work: find issues, fix them, re-audit until N consecutive clean passes. Converges on quality instead of trusting a single review pass.
- **Autonomous end-to-end process (gated phases)** — Run plan → implement → review as distinct phases, each with its own quality gate (audit, tests, review), fully hands-off. The structured replacement for raw "YOLO mode" autonomy.
- **Loom (software factory)** — Huntley's follow-on to Ralph: a fuller orchestrator that runs the loop plus planning, task decomposition, and verification as a continuous factory rather than a raw loop.

## Multi-agent orchestration

- **Subagent fan-out / orchestrator-workers** — A lead agent decomposes the task and dispatches parallel workers, each with its own fresh context window. The workhorse pattern for parallelizable work (search, review dimensions, per-file migrations); now native in Claude Code, Cursor, and Codex.
- **Pipeline (prompt chaining)** — Fixed sequence of stages, each agent's output feeding the next. Use when the workflow shape is known and deterministic control flow beats model-driven control flow.
- **Routing** — A classifier agent routes each input to a specialized handler (e.g., quick/standard/deep variants of the same role). Cheap requests stay cheap; hard ones get the heavyweight treatment.
- **Supervisor pattern** — A persistent manager agent monitors, assigns, and re-plans over a pool of workers. Called the 2026 production default in Google's multi-agent pattern catalog (which also canonized fan-out/fan-in, pipeline, debate, and swarm).
- **Best-of-N + judge (tournament)** — Generate N independent solutions from different angles, have judge agents score them, synthesize from the winner. Beats one-attempt-iterated when the solution space is wide; costs ~2.5× a single run.
- **Adversarial verification / multi-agent debate** — Spawn independent skeptics prompted to *refute* each finding or claim; only majority-surviving results count. Kills plausible-but-wrong output that a single self-review would keep.
- **LLM-as-judge / agent-as-judge** — Use an agent to evaluate outputs against a rubric, at scale. The 2026 "agent-as-a-judge" variant observes the full action trace, not just the final artifact, giving per-step feedback. Caveat: eval awareness (models behaving differently when they detect they're being evaluated) is now a named design concern.
- **Agent swarms / fleets** — Dozens-to-hundreds of agents on one goal: hierarchical orchestrators with ephemeral workers, a shared work ledger, and git-merge conflict resolution. Went from curiosity to production technique in 2026 (Thoughtworks Radar). Notable instances: Anthropic's Infinite Loop architecture (containerized agents self-assigning work via git-based file locks, specialized bugfix/dedup/perf/docs roles — used to build a C compiler), and Steve Yegge's Gas Town, evolved into **Gas City** (an SDK for arbitrary agent-team topologies, "dark factories") and **The Wasteland** (cross-user network of Gas Towns sharing a Wanted Board).
- **Git-worktree parallelism** — Each agent works in its own worktree of the same repo, so parallel agents can't trample each other; merge at the end. Now default best practice with near-universal native tool support, plus a tooling layer for per-agent DB/port isolation.

## Background and automation

- **Background / cloud agents** — Fire-and-forget: hand off a task, agent works asynchronously in a sandboxed environment and comes back with a PR (Claude Code web, Codex cloud, Devin, Copilot agents). Best for well-scoped tasks that don't need mid-flight steering.
- **Scheduled / cron agents (routines)** — Agents that run on a schedule: nightly dependency audits, morning triage, recurring reports. Automation for anything you'd otherwise do "every Monday."
- **Agent-in-CI** — Agents wired into the development pipeline: `@claude` mentions on issues/PRs, automatic PR review, auto-fix of failing builds. Puts the agent where the work already flows instead of in a separate chat.
- **Event-triggered automations** — Always-on agents fired by external events (GitHub webhooks, Slack messages) rather than schedules or mentions — e.g. Cursor Automations with cloud↔local handoff.
- **Headless / Agent SDK pipelines** — Drive the agent programmatically (Claude Agent SDK, `claude -p`) to build your own tools: batch processing, custom review bots, bespoke orchestrators. The agent as a library, not an app.
- **Managed Agents (brain/hands decoupling)** — Anthropic's 2026 architecture: stateless harness + durable external session log, `wake(sessionId)` recovery, elastic scaling of models and executors independently. Supersedes the tightly-coupled "harness owns the container" model for long-lived production agents.
- **Agent command centers** — Kanban-style boards for monitoring fleets of concurrent agents across projects (Devin's Command Center/Spaces), plus the Agent Client Protocol (ACP) for driving different vendors' agents from one editor.

## Context and memory

- **Memory files (CLAUDE.md / AGENTS.md)** — Persistent project instructions the agent loads every session: conventions, commands, gotchas. Treated as living documents; the highest-leverage cheap improvement to agent output quality.
- **Skills / slash commands** — Reusable procedural knowledge packaged as on-demand instructions (SKILL.md). Teach the agent a workflow once, invoke it forever; loads only when relevant, so it doesn't tax context.
- **Custom subagents** — Predefined agent roles with their own system prompt, tool set, and model tier (reviewer, debugger, researcher…). Routes each delegated task to a specialist instead of a generalist.
- **Context compaction / structured handoff** — Summarize a long session into a handoff note (or let the harness auto-compact) so work continues past the context window. The enabler for multi-hour tasks.
- **Harness design with context resets** — Deliberately reset context at phase boundaries with structured handoff artifacts (plans, state files) instead of one ever-growing conversation. Anthropic's 2026 answer to "context anxiety" in long-running autonomous builds.

## Tooling, verification, and guardrails

- **MCP (Model Context Protocol) tools** — Standard way to give agents new capabilities: databases, browsers, SaaS APIs, internal services. Extends what the agent can *do*, not just what it knows.
- **Hooks as deterministic guardrails** — Lifecycle hooks (pre/post tool use, on stop) that run real code: auto-format after edits, block dangerous commands, enforce checks. Guarantees the model can't forget, because it isn't the model doing it.
- **Auto mode (classifier-gated permissions)** — The sanctioned replacement for `--dangerously-skip-permissions`: input-injection screening plus output action-safety classification, with graduated permission tiers. Autonomy without the blank check.
- **Environment-first containment** — Sandbox the agent deterministically (containers, egress-control proxies validating request provenance) rather than relying on the model to refuse bad actions. Defense that holds even when the model is wrong.
- **Self-verification (verify-before-done)** — Agent must exercise its change end-to-end — run the app, drive the flow, observe behavior — not just pass typecheck/tests. Includes the 2026 niche variant of recording a **video demo** of the working feature as evidence.
- **Computer use / browser agents** — Agent drives a real GUI or browser (screenshots + clicks, or Playwright via MCP) to test UIs, fill forms, reproduce bugs. Closes the loop on anything with a visual surface.

## Foundational building blocks (still underneath everything)

- **ReAct (reason + act)** — Interleave reasoning steps with tool calls. The core loop inside every modern agent; you don't implement it anymore, but every pattern above is built on it.
- **Reflexion / self-critique** — Agent reviews its own output before finalizing. Weakest form of verification (same model, same blind spots) — prefer adversarial or external verification when stakes are real, but still useful as a cheap first filter.

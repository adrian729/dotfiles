---
name: ai-instruction-file-authoring
description: Author and evaluate Claude Code instruction files read by the model itself — skills (SKILL.md), subagents (.claude/agents/*.md), and CLAUDE.md memory files — write new, edit existing, or check against authoring rules (valid frontmatter where applicable, sharp triggers/routing, terse AI-directed voice, minimal tokens). Use whenever a SKILL.md, agent file, or CLAUDE.md (global or project) is the subject: creating, editing, auditing/reviewing, or judging well-formedness; explaining why a skill/agent over-/under-fires or mis-routes; or alongside audit-loop when audit targets these files (audit-loop drives loop, this supplies rubric). NOT for running a skill's task, executing/delegating to an agent, merely reading/quoting an instruction file's content, general non-instruction-file audits (audit-loop), nor configuring settings.json/hooks/permissions or harness-enforced automations (update-config).
---

# AI Instruction-File Authoring

Skill: `.claude/skills/<name>/SKILL.md`; agent: `.claude/agents/<name>.md`. Both `description` fields load every session (skill: trigger matching; agent: router delegation). Skill body loads only on trigger; agent body becomes subagent's system prompt. Optimize to that split: description = trigger/routing precision in fewest tokens; body = just enough rules for correct behavior.

CLAUDE.md (global `~/.claude/CLAUDE.md` or project `<repo>/CLAUDE.md`): no frontmatter, no trigger — loaded unconditionally every session, read as prose. Frontmatter and Description sections below don't apply; every other doctrine does.

**Audience: reader is always AI — router model choosing skills/agents, agent executing them, or model reading its own always-loaded memory — never a human.** Direct instructions, not documentation. No onboarding, motivation, or "this will help you" framing. Governs every choice below.

## Frontmatter
- Skill: `name` (lowercase-hyphenated, = dir name) + `description`.
- Agent: `name` (= filename minus `.md`) + `description`; optional `model`, `effort`. effort-* carriers: only `name`/`description`/`effort` — model passed at call time.
- `description`: one unwrapped inline line — never fold (`>-`) or wrap (see `markdown-no-wrap`). Preserve punctuation shape when editing — frontmatter parser tolerance proven only for existing form.

## Description
- Skill format: `<what it does, terse>. Use when <triggers>[; NOT when <anti-triggers>].` MUST end with "Use when …" — it fires the skill.
- Agent format — task agents: `Use PROACTIVELY to <task> — <scope>. NOT: <case> (<sibling>), <case> (<sibling>).`; explicit-ask carriers (effort-*): `Use when user explicitly asks <X> for delegated task.` NOT-clause routes each borderline case to its sibling.
- Triggers concrete: paraphrased user phrasings + situations, not just topic.
- Anti-triggers when sibling skill/agent or base agent could grab request — they route *elsewhere*, not *off*; legitimate co-fire? say so, keep anti-trigger narrow.
- Voice: imperative, condition-first. **you** only when trigger is Claude's own judgment; name **user** only to mark explicit ask vs. inference; never **I**.
- Word-level trim: drop articles/filler where meaning stays unambiguous — AI readers don't need them. Never cut semantic load: quoted phrasings, sibling names, verbs, NOT-clauses, numbers, slash-commands.
- Agents with quick/base/deep tiers: descriptions must be cumulative. Deep tier: `"cover everything <base> does AND additionally <its focus>"`. Base tier must encompass quick scope. NOT-clause still routes trivial/specialized cases away, but agent when invoked covers the full stack below it.

## Body
- Skill: one line what/why, then procedure. Numbered steps; **bold** labels + `→` for rules; inline code for literals. Reference other skills/commands by name, don't re-explain. Rarely-needed detail → sibling files, pointed to.
- Agent: one terse imperative line stating deliverable and report shape (e.g. `Analyze and explain, citing file:line.`).

## CLAUDE.md / memory files
- No frontmatter/trigger → skip those sections. Loaded every turn → token discipline applies doubly.
- One topic per `#` header; each line a behavior-changing directive — imperative rule, not description of current behavior; cut "why".
- No duplication across hierarchy: project file holds only repo-specific deltas, never restates global rules.
- Don't re-encode an existing skill's/agent's job — reference by name.
- Boundary: automated triggers ("whenever/each time/before/after X") belong in settings.json hooks (update-config), NOT CLAUDE.md — which holds only what the model decides/acts on at inference time. Flag and redirect misplaced requests.

## Token discipline
Two failure modes:
- **Bloat** → tokens wasted every trigger. Cut any line that doesn't change behavior.
- **Under-spec** → wrong behavior, then more tokens to catch and redo. Never cut a rule whose absence causes mistakes.
Test per line: "delete this — behavior change?" No → cut. Yes → keep, tighten. Then per word: "delete this word — meaning change?" No → cut.

## Audit checklist
1. **Trigger/Routing** — skill: ends with "Use when", triggers concrete, anti-triggers present where collision possible yet narrow. Agent: leads with "Use", NOT-clause names existing siblings. Mentally test: fires/routes when it should, co-fires where valid, quiet otherwise?
2. **Frontmatter** — valid; `name` = dir (skill) / filename (agent); only allowed fields. N/A for CLAUDE.md (none).
3. **Tokens** — every word earns its place; no human framing; no restating description; articles/filler cut where safe.
4. **Sufficiency** — rules cover needed cases; no gap forcing a guess; agent body states deliverable. Quick/base/deep tiers: each tier's description encompasses the tier below.
5. **Consistency** — body matches description; no contradictions; referenced skills/commands/siblings exist.
6. **CLAUDE.md** — one topic per header; no cross-hierarchy duplication; automations redirected to hooks/update-config, not memory.

Report by item; fix safe issues, flag judgment calls.

## Workflow
- **Write** → name+location → description (what + Use when/routing + anti-triggers) → body → checklist.
- **Update** → make the change → re-run checklist (esp. Trigger + Consistency).
- **Audit** → checklist only → report + fix safe issues.
- **CLAUDE.md** → skip name/description/frontmatter → header-grouped directives → checklist (minus Frontmatter, plus hook-boundary check).

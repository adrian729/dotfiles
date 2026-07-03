---
name: skill-agent-authoring
description: Author and evaluate Claude Code skills and subagents — write new, edit existing, or check against authoring rules (valid frontmatter, sharp triggers/routing, minimal tokens). Use whenever SKILL.md or agent file (.claude/agents/*.md) is the subject: creating, editing, auditing/reviewing, or judging well-formedness; explaining why a skill/agent over-/under-fires or mis-routes; or alongside audit-loop when audit targets skill/agent files (audit-loop drives loop, this supplies rubric). NOT for running a skill's task, executing/delegating to an agent, nor general non-skill/agent audits (that's audit-loop).
---

# Skill & Agent Authoring

Skill: `.claude/skills/<name>/SKILL.md`; agent: `.claude/agents/<name>.md`. Both `description` fields load every session (skill: trigger matching; agent: router delegation). Skill body loads only on trigger; agent body becomes subagent's system prompt. Optimize to that split: description = trigger/routing precision in fewest tokens; body = just enough rules for correct behavior.

**Audience: reader is always AI — router model choosing skills/agents, or agent executing them — never a human.** Direct instructions, not documentation. No onboarding, motivation, or "this will help you" framing. Governs every choice below.

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

## Body
- Skill: one line what/why, then procedure. Numbered steps; **bold** labels + `→` for rules; inline code for literals. Reference other skills/commands by name, don't re-explain. Rarely-needed detail → sibling files, pointed to.
- Agent: one terse imperative line stating deliverable and report shape (e.g. `Analyze and explain, citing file:line.`).

## Token discipline
Two failure modes:
- **Bloat** → tokens wasted every trigger. Cut any line that doesn't change behavior.
- **Under-spec** → wrong behavior, then more tokens to catch and redo. Never cut a rule whose absence causes mistakes.
Test per line: "delete this — behavior change?" No → cut. Yes → keep, tighten. Then per word: "delete this word — meaning change?" No → cut.

## Audit checklist
1. **Trigger/Routing** — skill: ends with "Use when", triggers concrete, anti-triggers present where collision possible yet narrow. Agent: leads with "Use", NOT-clause names existing siblings. Mentally test: fires/routes when it should, co-fires where valid, quiet otherwise?
2. **Frontmatter** — valid; `name` = dir (skill) / filename (agent); only allowed fields.
3. **Tokens** — every word earns its place; no human framing; no restating description; articles/filler cut where safe.
4. **Sufficiency** — rules cover needed cases; no gap forcing a guess; agent body states deliverable.
5. **Consistency** — body matches description; no contradictions; referenced skills/commands/siblings exist.

Report by item; fix safe issues, flag judgment calls.

## Workflow
- **Write** → name+location → description (what + Use when/routing + anti-triggers) → body → checklist.
- **Update** → make the change → re-run checklist (esp. Trigger + Consistency).
- **Audit** → checklist only → report + fix safe issues.

---
name: skill-authoring
description: >-
  Author and evaluate Claude Code skills — write new ones, edit existing, or check them
  against the authoring rules (valid frontmatter, sharp triggers, minimal tokens). Use
  whenever a skill/SKILL.md is the subject: creating, editing, auditing/reviewing, or reading
  one to judge whether it's well-formed or needs changes; explaining why a skill over- or
  under-fires; or alongside audit-loop when an audit targets a skill (audit-loop drives the
  loop, this supplies the skill rubric). NOT for running a skill's actual task, nor for
  general non-skill code/work audits (that's audit-loop).
---

# Skill Authoring

A skill is `.claude/skills/<name>/SKILL.md`. The `description` loads every session; the body
loads only on trigger. Optimize to that split: description = trigger precision in fewest
tokens; body = just enough rules for correct behavior.

**Audience: the reader is always an AI agent that will execute the skill — Claude, Claude
Code, or any other agent/AI tool that consumes skills — never a human.** Write to that reader:
direct instructions, not documentation. No onboarding, motivation, marketing, or "this will
help you" framing — an agent needs the rule and the procedure, nothing else. This governs every
choice below, in the description and the body alike.

## Frontmatter
- `name`: lowercase-hyphenated, matches the directory.
- `description`: required; the most important line (see below). Use `>-` (folded) when multi-line.

## Description
Format: `<what it does, terse>. Use when <triggers>[; NOT when <anti-triggers>].`
- MUST end with the **"Use when …"** clause — it's what fires the skill.
- Triggers must be concrete: paraphrased user phrasings + situations, not just a topic.
- Add **anti-triggers** when a sibling skill or the base agent could grab the request —
  prevents over-firing and mis-routing.
- Anti-triggers route a request *elsewhere*, not *off* — if a skill can legitimately co-fire
  (e.g. one drives the loop, another supplies the rubric), say so in the triggers and keep the
  anti-trigger narrow; an over-broad anti-trigger suppresses valid firing.
- Voice: imperative, condition-first (the reader executes, see Audience). Say **you** only
  when the trigger is Claude's own judgment (`a task you judge heavy`); name **the user** only
  to mark an explicit ask vs. an inference; never **I**.
- No fluff or marketing — every word is paid every session.

## Body
- One line of what/why, then the procedure. No preamble, no restating the description.
- Numbered steps for procedures; **bold** labels + `→` for rules; inline code for literals.
- Reference other skills/commands by name (e.g. `/code-review`), don't re-explain them.
- Move rarely-needed detail (references, scripts, templates) into sibling files and point to
  them — loaded on demand, keeps SKILL.md lean.

## Token discipline
Two failure modes:
- **Bloat** → tokens wasted on every trigger. Cut any line that doesn't change behavior.
- **Under-spec** → wrong behavior, then more tokens to catch and redo it. Never cut a rule
  whose absence causes mistakes.

Test each line: "delete this — does behavior change?" No → cut. Yes → keep, tighten.

## Audit checklist
1. **Trigger** — description ends with "Use when"; triggers concrete; anti-triggers present
   where collision is possible, yet narrow enough not to suppress valid co-firing. Mentally
   test: fires when it should, co-fires where it should, stays quiet when not?
2. **Frontmatter** — valid YAML; `name` lowercase-hyphenated and equal to the dir name.
3. **Tokens** — every line earns its place; no bloat, no human-oriented framing
   (onboarding/motivation/tutorial/marketing), no restating the description.
4. **Sufficiency** — rules cover the cases needed for correct behavior; no gap forcing a guess.
5. **Consistency** — body matches description; no internal contradiction; references valid.

Report by item; fix the safe issues, flag judgment calls.

## Workflow
- **Write** → choose name+dir → draft description (what + Use when + anti-triggers) → draft
  body → run the checklist.
- **Update** → make the change → re-run the checklist (esp. Trigger + Consistency).
- **Audit** → run the checklist only → report + fix safe issues.

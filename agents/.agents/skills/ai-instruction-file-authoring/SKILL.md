---
name: ai-instruction-file-authoring
description: Write or review skills (SKILL.md), agent definitions, and memory files (CLAUDE.md/AGENTS.md); diagnose their triggering or routing. Use for instruction-file changes or audits, not for executing the tasks those files describe.
---

# AI Instruction-File Authoring

Write concise instructions an agent can reliably apply. Include the context and constraints needed for correct decisions; assume the model already knows general concepts and routine techniques.

## Workflow

1. **Establish scope.** Identify the intended outcome, target tools, file type, and requested mode. Respect review-only requests; edit when requested. For revisions, identify the behavior to preserve or correct before adding rules. Keep fixes specific to the demonstrated problem.
2. **Inspect context.** Read the file and relevant inherited instructions. Determine what each target tool discovers and loads, including imports and conditional references. Check overlapping guidance and available dependencies before removing duplication or adding references. Keep repository conventions scoped to that repository.
3. **Draft.** Use the file-type guidance below. Specify needed inputs, decisions, outputs, and completion criteria. Use exact steps for fragile operations and leave judgment where valid approaches vary. Include exceptions or examples when they resolve likely ambiguity. Preserve precise tool-specific paths and mechanics where the task requires them.
4. **Validate.** Parse frontmatter or configuration when present; check required fields, supported options, naming, and location against the target tool's format. Consult current documentation when uncertain; preserve valid existing options. Check for conflicting instructions, including inherited rules, and ensure descriptions match their bodies. Verify references to files, commands, skills, and agents are available in the intended environment. For routing changes, examine requests that should and should not match. For substantial behavioral changes, exercise representative tasks where practical and compare with previous behavior. Distinguish actual runs from reasoning through examples.
5. **Compress and report.** Apply the token guidance below, then check that necessary requirements and distinctions survived. In a review, report concrete issues, likely effects, and proposed changes. After editing, summarize what changed, what was checked, and any untested behavior.

## File types

- **Skills:** Use the description to identify the task and when to select it. Prefer concrete situations; add exclusions only for likely collisions. No exact phrase is required. Put the executable workflow and its decision points in the body. Move conditional detail into supporting files when useful, with explicit paths and instructions for when to read them. Keep essential constraints in the entrypoint.
- **Agent definitions:** Describe the delegated responsibility and when it fits. Include the scope, constraints, task guidance, and expected result needed to perform that role. Body length follows the task. Encourage proactive delegation only when intended; tier relationships depend on the actual agent design. Validate metadata separately for each tool rather than assuming agents share a schema.
- **Memory and project instructions:** Record persistent, non-obvious facts, constraints, and conventions that affect work. Retain short rationale when it helps the agent apply a rule correctly. Place guidance where it loads for the intended scope; remove duplication only after checking inheritance. Use the tool's automation mechanism when an action must execute at a supported lifecycle event; conditional advice such as “before editing, inspect symlink targets” can remain in prose.

## Token discipline

- Prioritize frequently loaded descriptions and instructions. Check actual loading behavior; discovery metadata, invoked bodies, and optional references have different context costs.
- Remove irrelevant policy, repetition, and obvious explanations before trimming individual words. Preserve clear sentences, useful examples, and rationale that prevent mistakes. Avoid arbitrary line limits or reduction targets.
- Keep small files self-contained. Split out material only when selective loading helps; make each reference's purpose clear so the agent can find it without reading everything.
- Preserve intended invocation behavior when shortening descriptions. Change visibility or invocation settings only within the requested scope. If reviewing Claude's `skillOverrides`, `name-only` still exposes the skill's name to the model; it does not make the skill manual-only.

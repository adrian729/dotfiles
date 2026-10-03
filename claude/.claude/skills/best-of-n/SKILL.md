---
name: best-of-n
description: "Generate independent candidate solutions, compare them against the same rubric, and select or combine the strongest result. Use when explicitly asked for best of N, a tournament, or competing approaches; not for a single attempt or an iterative critique loop."
---

# Best-of-N

Produce separate solutions to the same task before judging them. Independence, a shared rubric, and validation of the selected result define this workflow.

## 1. Define the comparison

Use the requested positive candidate count. If omitted, use five candidates, or seven for explicitly critical work, subject to the user's budget. State the count and any necessary reduction of a default; do not silently reduce an explicit N.

Derive the rubric from the task's acceptance criteria before generating candidates. Separate mandatory requirements from preferences. Use weights or numerical scores only when they clarify a real tradeoff; a high preference score cannot compensate for a failed requirement. Resolve material ambiguity, then keep the rubric stable across candidates.

Assign distinct approaches that could reasonably solve the whole task. Differences should be substantive, such as algorithm, architecture, or explanatory structure. These are competing solutions, not pieces of a divided task. Routine choices of angles and rubric do not require an approval gate.

## 2. Generate independently

- Use separate worker contexts. Give every worker the same task, constraints, rubric, and relevant starting state, plus its assigned approach. Do not expose other candidates or their critiques.
- For code, include relevant uncommitted work in the starting state. Give each worker an isolated workspace or request a patch without target edits; workers must not concurrently modify the shared target.
- Run workers in parallel when resources permit, otherwise sequentially in separate contexts. Use available tools and models within the existing cost constraints; do not assume a model is free.
- Collect the candidate, its assumptions, and validation evidence. Retry a failed worker once within the budget. If fewer than N candidates succeed, continue with those available but mark the comparison incomplete; if none succeed, stop. If independent contexts are unavailable, stop and report the limitation.

## 3. Judge

Give a separate judge the common task, rubric, necessary context, and candidate artifacts. Instruct it to evaluate without editing candidates. Use neutral candidate labels; judge the artifacts and evidence rather than their model or tier. Run relevant objective checks where practical. Reject candidates that violate mandatory requirements before comparing preferences. If the judge cannot complete the comparison, stop and report it as incomplete.

If no candidate satisfies the requirements, correct the strongest attempt within the remaining budget and have it judged under the original rubric. If it still fails, stop and report an incomplete result with the remaining gaps. Explain meaningful ties using the user's priorities; ask only when choosing between unresolved tradeoffs needs their judgment.

## 4. Select and validate

Start with the strongest qualifying candidate. Incorporate another candidate's contribution only when it improves that result coherently; combining candidates is optional. Apply the chosen result without overwriting unrelated work, then validate the actual integrated artifact. Candidate scores alone do not validate a synthesis.

Keep enough candidate state to explain or recover the selection until the final result is saved. Clean up only disposable artifacts created by this run.

## Report

Respect the requested reporting detail. Include the requested and completed counts, concise comparison, selection rationale, final validation, and remaining tradeoffs. Describe model usage or cost only from observed information; do not invent savings.

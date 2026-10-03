---
name: evaluator-optimizer
description: "Generate an artifact, have a separate evaluator judge it against a fixed rubric, and produce revised candidates until it passes or reaches a limit. Use for an explicit evaluator-optimizer or generator-critic loop; use audit-loop for auditing existing work and best-of-n for competing independent solutions."
---

# Evaluator-Optimizer

Keep generation and evaluation separate. Each round produces a complete candidate judged against the same acceptance criteria.

## Setup

- Establish the artifact, allowed scope, and rubric from the request. Each criterion needs a clear pass condition; qualitative criteria can use concrete examples or observable qualities. Resolve material ambiguity before starting, without requiring confirmation of already specified choices.
- Fix the rubric before generation. Evaluators may flag a defect in it, but may not add requirements or lower thresholds to obtain a pass. If resolving a defect changes the intended outcome, ask the user; re-evaluate candidates under any revised rubric.
- Use the user's round limit, otherwise three rounds. Honor larger explicit limits rather than clamping them. A round includes one candidate and its evaluation; retries also consume the overall time and cost budgets.
- Choose available generation and evaluation tools within existing model and cost constraints. The evaluator must have a separate, fresh context. Different models are optional unless requested and do not guarantee independent errors. If a requested pairing or separate context is unavailable, stop and report the blocked step.
- Preserve the original state and complete candidate versions, including new files and relevant uncommitted changes. Use isolated outputs where needed so rejected candidates do not overwrite the user's work.

## Each round

1. **Generate.** Give a fresh generator the task, scope, rubric, relevant context, and previous candidate plus actionable feedback when available. Require a complete candidate, not just a list of suggested edits. It may retain correct content; every round must address the feedback and preserve satisfied requirements. Keep writes within the allowed scope.
2. **Evaluate.** Give a fresh evaluator the task, scope, fixed rubric, complete candidate, and context or tools needed to verify it. Exclude generator reasoning and prior verdicts. Instruct it to inspect without editing and return pass/fail per criterion with evidence. Each failure must identify the gap and what would satisfy the criterion. Missing evidence for a required check is not a pass.
3. **Record.** Save the candidate and its verdict. Track the strongest candidate against mandatory requirements and the user's priorities; neither the newest version nor the fewest failing criteria necessarily makes it best.
4. **Decide.** Stop when every criterion and required objective check passes. Otherwise give the generator the specific failures for the next round, subject to the stopping rules below. Evaluate the whole rubric again to catch regressions.

If a generator or evaluator call fails or returns unusable output, retry it once within the remaining budget. If it still fails, stop with the best evaluated candidate, if any, and the failure reason. If no candidate was evaluated, preserve the original state and report that no evaluated result is available.

## Stop and deliver

- **Passed:** select the passing candidate and validate its application to the intended target. If integration changes the artifact or fails a required check, correct and re-evaluate the result within the remaining budget; otherwise report it as incomplete.
- **Limit reached:** stop at the round, time, or cost limit. Deliver the strongest evaluated candidate with unmet criteria clearly identified.
- **Stalled or blocked:** stop if repeated revisions make no meaningful progress or a requirement cannot currently be satisfied. The same failing criteria across rounds alone do not prove a stall; check whether the artifact or evidence is improving.
- **Rubric defect:** report conflicting or untestable requirements. Preserve the current candidates while resolving the defect; do not declare success under an altered rubric without re-evaluation.

Apply the selected result only within the authorized scope, preserving unrelated changes. Keep candidate versions needed to explain an incomplete result; remove only disposable artifacts created by the run after the chosen output is saved.

Report the selected artifact, rounds used, actual evaluator arrangement, validation, and unresolved criteria at the requested level of detail. A successful authorized run needs no automatic final acceptance question.

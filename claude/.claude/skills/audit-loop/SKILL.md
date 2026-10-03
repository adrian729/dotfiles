---
name: audit-loop
description: "Repeatedly audit and fix a target, then confirm it with two consecutive clean passes. Use when explicitly asked for an audit loop or to keep auditing until clean; a one-pass review does not need this workflow."
---

# Audit Loop

Review, triage, fix, and repeat. Require two consecutive clean passes to declare convergence; unresolved issues remain visible.

## Setup

- Use the named target, or infer the most recent work when unambiguous. Record its scope and acceptance criteria. For conversational plans or analysis, provide the actual text to reviewers.
- Honor requested iteration, time, and cost limits. A pass covers the whole target; splitting it does not multiply or reset the budget. Without a supplied cap, continue while making progress toward confirmation.
- Establish whether fixes are authorized. A review-only request keeps the target unchanged. Use available reviewers and implementers within the current tool and model constraints.

## Each pass

1. **Review.** Use a fresh reviewer context, instructed to inspect without editing. Supply the target, requirements, and relevant surrounding context, excluding earlier verdicts and the author's reasoning. Focus on correctness, missing requirements, contradictions, and relevant risks. For code, use tests where they provide evidence; for plans and documents, check feasibility, accuracy, and references.
2. **Triage.** Reconcile findings with the existing issue ledger. Each significant finding needs a location, supporting evidence, and concrete impact. Reject unsupported findings with a reason. Track optional improvements separately; greater review depth does not turn cosmetic preferences into defects.
3. **Fix.** Correct supported significant issues within the authorized scope, then run checks appropriate to the change. Leave optional improvements unless requested. Delegate fixes only when useful, with clear ownership. Record anything that remains unresolved and why.
4. **Count.** A pass is clean only if its review completes, it finds no supported significant issue, it has no unresolved significant issue in the ledger, and it makes no fixes. Increment the clean streak for a clean pass; otherwise reset it. Fixing an issue during a pass requires a later pass to confirm the result.

The orchestrating agent can triage, fix, and report; separate agents for these roles are optional. Fresh reviewer contexts are required for independent confirmation. If the environment cannot provide them, stop and report the blocked gate.

For large targets, reviewers may cover disjoint subsets in the same pass. Give them access to related context and include a review of interfaces and shared assumptions before counting the pass as complete.

## Stop and report

- **Converged:** two consecutive clean passes. Optional improvements may remain and do not restart the loop.
- **Limit reached:** stop at the user's cap or budget, including when only one clean pass has completed. Report the unconfirmed state.
- **Stalled or blocked:** stop when only issues that cannot currently be resolved remain, or repeated fixes make no meaningful progress. Keep those issues unresolved; repetition never downgrades their severity.
- **Review-only:** findings remain open for reporting. Do not start fixing them to obtain a clean result.

Keep a compact ledger of findings, fixes, validation, and pass outcomes. Report the stopping reason and unresolved issues with the decisions they need, respecting the requested reporting detail. A deferred significant issue prevents convergence.

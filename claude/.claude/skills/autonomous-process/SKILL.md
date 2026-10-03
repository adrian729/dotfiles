---
name: autonomous-process
description: "Carry out an explicitly requested plan, implement, and review workflow with audit gates, without routine approval pauses. Use for a requested full autonomous process; ordinary implementation or a single review does not require this workflow."
---

# Autonomous Process

Complete plan → implementation → final review in order. Advance through the audit gates on evidence, while making routine decisions within the user's request.

## Setup

- Establish the intended result, acceptance criteria, scope, and any iteration, time, or cost limits from the request and available context. Ask only for missing information or a decision that materially affects the result.
- Use existing permission settings and authorization. This workflow does not require enabling auto-accept or changing safeguards.
- Read [audit-loop](../audit-loop/SKILL.md) for the review gates. Honor overall limits across phases and nested reviews; reset a limit only when the user specified it per phase.
- Delegate separable work when useful and permitted. Give each worker the requirements, owned scope, relevant context, and expected result; prevent overlapping writes.

## Phases

1. **Plan.** Inspect the relevant state and produce a plan proportional to the task, covering the approach, dependencies, and validation. Planning may create plan artifacts, but implementation changes wait until the plan passes its audit. Run audit-loop on the plan, fixing gaps in completeness, consistency, feasibility, and alignment with the request. Advance only after its two clean passes.
2. **Implement.** Execute the audited plan and validate the result. If evidence requires a material change in approach, update and re-audit the affected plan before dependent implementation. Run audit-loop on the implementation, including integration across delegated work. Advance only after its two clean passes and required checks.
3. **Final review.** Use a fresh reviewer to assess the complete result against the original request and acceptance criteria. Check that the pieces work together and required outcomes were actually delivered. Significant findings reopen the implementation audit within the remaining budget; its confirming passes must cover the affected end-to-end behavior.

Continue between phases without routine approval requests. If a gate stalls or a limit is reached, retain the current work and report the unmet gate. If a genuine user decision blocks part of the task, continue independent work where possible.

## Completion

Declare completion only when the required gates and task checks have passed. Report the result, phase outcomes, relevant validation, and unresolved decisions at the requested level of detail. Include full iteration logs only when requested or needed to explain a blocker.

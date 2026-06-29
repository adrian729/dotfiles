---
name: autonomous-process
description: Drive a task end-to-end hands-off through three gated phases — plan, implement, final review — running an audit-loop at each gate, then emit a full per-phase process report; runs the whole task in auto-mode. Use when the user EXPLICITLY asks to run a task autonomously / "the full process" / "plan it, build it, and review it on your own" / "end to end without me". NOT triggered by merely being in or selecting auto-mode; NOT for a one-off audit/review (use audit-loop or /code-review), nor a plain "just implement X" with no plan→review lifecycle.
---

# Autonomous Process

Run a task through its full lifecycle with no hand-holding: plan → implement → final review, each gate closed by an `audit-loop`, then report the whole run. The rules below always hold.

## Auto-mode (first action, before any work)
This skill always runs hands-off — there is no interactive variant. Your **very first action**, before Phase 1 or any planning, is to get into auto-mode (auto-accepting actions, no per-step approval): switch it automatically if you can; otherwise prompt the user once to enable it (shift+Tab → auto-accept) and wait for confirmation. This is the **only** interactive moment — after it the entire run, planning included, proceeds unattended. The hard rules below still hold with auto-mode on.

## Hard rules
- **No code in Phase 1.** Never edit/write project files during planning or its audit loop — even in auto-mode. Plan artifacts only. Touch code before the plan converges only for a reason you state explicitly.
- **Subagents when the task needs it** — many files, a large file that splits cleanly, multi-source investigation, or parallelizable audit (see `audit-loop` split mode). Spawn them in parallel (one message, multiple calls). Give each enough context plus a structured return format so the main thread isn't left guessing; keep prompts and returns concise. Don't spawn for trivial single-file work.
- **Token discipline** — concise everywhere, but never so terse a step fails or an agent returns too little to act on.

## Phases
1. **Plan** — produce an implementation plan (the `Plan` agent for design, `Explore` for investigation, or inline if small). No code changes. Then `audit-loop` the plan: completeness vs intent, contradictions, unstated assumptions, missing edge cases, feasibility. Iterate to convergence. Code stays untouched until the plan passes.
2. **Implement** — execute the converged plan; subagents per the rule above. Then `audit-loop` the implementation: correctness, security, edge cases, tests, simplification/reuse (reuse `/code-review`, `/security-review`, `/simplify`, `/verify`).
3. **Final review** — fresh end-to-end pass over the whole change against the original intent and the plan. Issues found → `audit-loop` again until clean. None → done.

Run 1→2→3 without stopping for approval — the only pause is the one-time auto-mode setup above (and any deviation you explicitly state).

## Report (always, at the end)
One report, three sections — **Plan**, **Implementation**, **Final review**. Per section:
- summary of what was produced/done;
- audit-loop outcome: findings + fixes + skips per iteration (and per subagent, if split), and why it stopped.

End with **Needs your attention**: every deferred/skipped fix and open decision.

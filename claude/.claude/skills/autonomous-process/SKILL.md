---
name: autonomous-process
description: Drive task end-to-end hands-off through three gated phases — plan, implement, final review — running audit-loop at each gate, then emit full per-phase process report; runs whole task in auto-mode. Use when user EXPLICITLY asks to run task autonomously / "the full process" / "plan it, build it, and review it on your own" / "end to end without me". NOT triggered by merely being in or selecting auto-mode; NOT for one-off audit/review (use audit-loop or /code-review), nor plain "just implement X" with no plan→review lifecycle.
---

# Autonomous Process

Run task through its full lifecycle with no hand-holding: plan → implement → final review, each gate closed by `audit-loop`, then report whole run. Rules below always hold.

## Auto-mode (first action, before any work)
This skill always runs hands-off — there is no interactive variant. Your **very first action**, before Phase 1 or any planning, is to get into auto-mode (auto-accepting actions, no per-step approval): switch it automatically if you can; otherwise prompt user once to enable it (shift+Tab → auto-accept) and wait for confirmation. This is the **only** interactive moment — after it the entire run, planning included, proceeds unattended. Hard rules below still hold with auto-mode on.

## Hard rules
- **No code in Phase 1.** Never edit/write project files during planning or its audit loop — even in auto-mode. Plan artifacts only. Touch code before plan converges only for reason you state explicitly.
- **Subagents when task needs it** — many files, large file that splits cleanly, multi-source investigation, or parallelizable audit (see `audit-loop` split mode). Spawn them in parallel (one message, multiple calls). Give each enough context plus structured return format so main thread isn't left guessing; keep prompts and returns concise. Don't spawn for trivial single-file work.
- **Token discipline** — concise everywhere, but never so terse a step fails or agent returns too little to act on.

## Phases
1. **Plan** — produce implementation plan (`Plan` agent for design, `Explore` for investigation, or inline if small). No code changes. Then `audit-loop` the plan: completeness vs intent, contradictions, unstated assumptions, missing edge cases, feasibility. Iterate to convergence. Code stays untouched until plan passes.
2. **Implement** — execute converged plan; subagents per rule above. Then `audit-loop` the implementation: correctness, security, edge cases, tests, simplification/reuse (reuse `/code-review`, `/security-review`, `/simplify`, `/verify`).
3. **Final review** — fresh end-to-end pass over whole change against original intent and plan. Issues found → `audit-loop` again until clean. None → done.

Run 1→2→3 without stopping for approval — only pause is one-time auto-mode setup above (and any deviation you explicitly state).

## Report (always, at the end)
One report, three sections — **Plan**, **Implementation**, **Final review**. Per section:
- summary of what was produced/done;
- audit-loop outcome: findings + fixes + skips per iteration (and per subagent, if split), and why it stopped.

End with **Needs your attention**: every deferred/skipped fix and open decision.

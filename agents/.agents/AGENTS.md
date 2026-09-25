# Response style

Chat replies: light telegraphic — drop articles/filler where meaning stays instantly clear; keep full sentences for nuanced explanations. Never trade clarity for brevity — ambiguity costs more than saved tokens.
Scope: conversation replies only. NOT code, code comments, commit messages, PR text, or user-facing docs.

# Pre-spawn workflow

If an agent description contains "Pre-pass:", execute the instruction before
spawning. Include results under [Pre-pass:] in the spawn prompt. Cache across
loops; re-run after code changes.

# Delegation

Delegate implementation and review to subagents by default — don't do substantive work inline when a specialized subagent exists; pick from whatever the harness provides. Spawn independent subtasks in parallel. Inline only for trivial (<5 lines), conversational, or single-file mechanical edits. If user explicitly asks primary to do it directly / not to delegate, honor it — do inline.

# Effort gating

Before spawning reviewer for code diffs: if diff is small/routine AND not on sensitive paths,
use reviewer-quick instead of reviewer. Sensitive paths: auth, crypto, payment,
secrets, infra. Does not apply to doc/plan targets — reviewer is default.

# Paid model usage

Free models are the default when delegating to OpenCode subagents (the agents defined in opencode.json's `agent` block). To use a paid model for a given task, ask the user for permission first — `y/N/always`. The answer is N (free) unless the user explicitly opts in.

When asking, list the paid model and its reason (e.g. "auditor needs qwen3.7-max for thorough security analysis, $0.32/session"). If the user says "always" for a model, remember it for the remainder of the session — re-ask next session.

Query available models:

- `opencode-models free` — free-tier models only
- `opencode-models agents <name>` — full priority list for an agent (paid + free)

# Code comments

- Never add any comments unless it was explicitly asked. Don't ever ignore this rule.

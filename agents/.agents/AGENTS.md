# Response style
Chat replies: light telegraphic — drop articles/filler where meaning stays instantly clear; keep full sentences for nuanced explanations. Never trade clarity for brevity — ambiguity costs more than saved tokens.
Scope: conversation replies only. NOT code, code comments, commit messages, PR text, or user-facing docs.

# Pre-spawn workflow
If an agent description contains "Pre-pass:", execute the instruction before
spawning. Include results under [Pre-pass:] in the spawn prompt. Cache across
loops; re-run after code changes.

# Effort gating
Before spawning reviewer for code diffs: if diff is small/routine AND not on sensitive paths,
use reviewer-quick instead of reviewer. Sensitive paths: auth, crypto, payment,
secrets, infra. Does not apply to doc/plan targets — reviewer is default.

# Code comments
Comments explain WHY, not WHAT — code already shows what it does.
Three valid uses:
- What: terse one-line summary at top of file/module/function
- How: high-level approach inside a function if non-obvious
- Why: rationale for a statement or design choice the code can't express

Never: restate the obvious, add section headers (`# SETUP`), label trivial blocks,
or explain what a variable/function name already says. Write for a reader who sees
the code but not the reasoning behind it.

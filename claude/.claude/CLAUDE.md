# Response style
Chat replies: light telegraphic — drop articles/filler where meaning stays instantly clear; keep full sentences for nuanced explanations. Never trade clarity for brevity — ambiguity costs more than saved tokens.
Scope: conversation replies only. NOT code, code comments, commit messages, PR text, or user-facing docs.

# Fable quota fallback
Agent tool call to a fable-pinned agent fails with quota/usage-limit error → retry once immediately, same agent, with call-time `model: opus` override, no confirmation needed. Always report it: flag the substitution the moment it happens, and summarize again in the end-of-task wrap-up.

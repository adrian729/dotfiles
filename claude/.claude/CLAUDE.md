@../../agents/.agents/AGENTS.md

# Fable quota fallback
Agent tool call to a fable-pinned agent fails with quota/usage-limit error → retry once immediately, same agent, with call-time `model: opus` override, no confirmation needed. Always report it: flag the substitution the moment it happens, and summarize again in the end-of-task wrap-up.

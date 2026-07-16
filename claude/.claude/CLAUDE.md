@../../agents/.agents/AGENTS.md

# Fable quota fallback
Agent tool call to a fable-pinned agent fails with quota/usage-limit error → retry once immediately, same agent, with call-time `model: opus` override, no confirmation needed. Always report it: flag the substitution the moment it happens, and summarize again in the end-of-task wrap-up.

# Context pressure routing
Hourly/weekly context near full (75%+) → before spawning any subagent, consider offloading the subtask to `opencode-task` (zero context cost) or running it through OpenCode's own agents via `opencode run --agent <name> --auto`. For simple text-only work (summarize, classify, short generate), pipe to `llm` (local ollama) — but only for truly simple stuff; local models lack depth for real coding or reasoning.

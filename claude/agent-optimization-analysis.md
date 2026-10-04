# Agent optimization analysis (archived)

The former proposal used mandatory discovery pre-passes, routing gates, and delegated intermediate steps to reduce model costs. Those requirements have been removed from the active configuration. Its savings estimates were hypothetical and were never validated by measurements; they are not retained as guidance.

Current behavior is defined by `.claude/agents/` and summarized in [agents-reference.md](agents-reference.md). Agent descriptions identify useful roles without requiring delegation. Model and effort assignments remain defaults; explicit workflow skills define their own process when requested.

The original proposal is available in Git history. Reconsider an optimization only against a concrete problem, comparing task quality, latency, and actual usage before adopting it.

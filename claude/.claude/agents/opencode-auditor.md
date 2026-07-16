---
name: opencode-auditor
description: "Use PROACTIVELY to delegate security/compliance audit to OpenCode's auditor subagent (enforced read-only, restricted bash, best model). Use for security review, vulnerability assessment, compliance checks, sensitive-path audit (auth/crypto/payment/secrets/infra). NOT: standard review (opencode-reviewer)."
model: haiku
effort: low
---
Run `opencode-task <name> --agent auditor "Run subagent: auditor. Task: <task>"` in a throwaway worktree. Return the result verbatim. Use a descriptive, unique name for the worktree related to the task.

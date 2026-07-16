---
description: "Implement features, fix bugs, write tests, refactor — full tool access. Use when coding work benefits from an isolated worktree with its own model. NOT: quick scaffolding (implementer-quick)."
mode: all
hidden: true
# model: managed in opencode.json agent block. Re-run install.sh after changes.
steps: 30
permission:
  edit: allow
  bash:
    "*": allow
    "git push": deny
    "git push *": deny
    "npm publish": deny
    "npm publish *": deny
    "gh release": deny
    "gh release *": deny
    "docker push": deny
    "docker push *": deny
    "terraform apply": deny
    "terraform apply *": deny
    "kubectl apply": deny
    "kubectl apply *": deny
    "cargo publish": deny
    "cargo publish *": deny
  webfetch: ask
  websearch: ask
---
First, grep for the target symbol across the codebase to understand existing patterns and conventions. Then implement the requested change and verify it (lint, test). Return a summary of what was done and key files changed.

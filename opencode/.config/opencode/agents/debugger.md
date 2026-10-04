---
description: "Diagnose failures, reproduce bugs, and investigate errors with editing and shell access. Can run through opencode-task in a separate worktree."
mode: all
hidden: true
# model: managed in opencode.json agent block. Re-run install.sh after changes.
steps: 40
permission:
  edit: allow
  # deny list below fully replaces (doesn't merge with) opencode.json's top-level
  # bash permission — keep it in sync across the three agent copies.
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
---
Reproduce the failure where practical, identify the root cause with evidence, and verify any requested fix. Preserve relevant evidence when summarizing logs. Report the cause, changes, checks, and remaining uncertainty with file references.

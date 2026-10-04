---
description: "Implementation plans, architecture, API/schema design, and trade-off analysis with editing disabled and restricted shell commands."
mode: all
hidden: true
# model: managed in opencode.json agent block. Re-run install.sh after changes.
permission:
  edit: deny
  task: deny
  bash:
    "*": deny
    "git log*": allow
    "git diff*": allow
    "git ls-tree*": allow
    "git ls-files*": allow
    "git show*": allow
    "git status*": allow
    "grep *": allow
    "rg *": allow
    "find *": allow
    "ls *": allow
---
Inspect the relevant architecture and constraints. Produce a plan or design naming critical files, dependencies, trade-offs, and validation. Do not modify files or run commands with side effects.

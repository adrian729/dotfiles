---
description: "Web research, documentation lookups, and library comparisons with editing disabled and web access. Use explore for codebase discovery."
mode: all
hidden: true
# model: managed in opencode.json agent block. Re-run install.sh after changes.
steps: 40
permission:
  edit: deny
  task: deny
  bash:
    "*": deny
    "grep *": allow
    "rg *": allow
    "ls *": allow
  webfetch: allow
  websearch: allow
---
Gather primary sources for the question, check their dates and applicability, and synthesize a sourced answer. Distinguish evidence from inference and unresolved uncertainty. Do not modify files or run commands with side effects.

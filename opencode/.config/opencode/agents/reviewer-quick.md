---
description: "Quick sanity check on small diffs or triage — enforced read-only, cheap model. Use for small/routine changes, 'does this look right', or classifying issues. NOT: standard review (reviewer), security audit (auditor)."
mode: all
hidden: true
# model: managed in opencode.json agent block. Re-run install.sh after changes.
steps: 15
permission:
  edit: deny
  bash:
    "*": deny
    "git diff*": allow
    "git log*": allow
    "grep *": allow
    "rg *": allow
    "ls *": allow
  webfetch: ask
  websearch: ask
---
First, skim the diff or input to understand scope. Then do a quick pass and report only clear problems with references (file:line for code, section for docs/plans). No deep analysis.

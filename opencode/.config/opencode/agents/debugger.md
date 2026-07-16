---
description: "Diagnose failures, reproduce bugs, investigate errors — full tool access. Use when debugging benefits from running tests in an isolated worktree without dirtying your checkout. NOT: trivial issues you can resolve directly."
mode: all
hidden: true
# model: managed in opencode.json agent block. Re-run install.sh after changes.
steps: 40
permission:
  edit: allow
  # deny list below fully replaces (doesn't merge with) opencode.json's top-level
  # bash permission — keep in sync with it and with implementer.md/implementer-quick.md.
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
If the input contains long logs or stack traces (>200 lines), summarize them first. Then reproduce the failure, identify root cause with evidence, and report file:line references for problematic code. Rule out alternatives before concluding.

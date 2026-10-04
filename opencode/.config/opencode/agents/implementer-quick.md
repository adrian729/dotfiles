---
description: "Scaffolding, boilerplate, and small self-contained edits. Use implementer for broader implementation work."
mode: all
hidden: true
# model: managed in opencode.json agent block. Re-run install.sh after changes.
steps: 15
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
Inspect enough context to follow existing conventions, make the requested change, and perform checks proportionate to it. Report changes and validation.

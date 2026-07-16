---
description: "Quick scaffolding, boilerplate, small self-contained edits — full tool access, cheap model. Use for mechanical code generation or trivial changes. NOT: real implementation (implementer)."
mode: all
hidden: true
# model: managed in opencode.json agent block. Re-run install.sh after changes.
steps: 15
permission:
  edit: allow
  # deny list below fully replaces (doesn't merge with) opencode.json's top-level
  # bash permission — keep in sync with it and with debugger.md/implementer.md.
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
First, grep for context if needed. Then produce the requested code quickly. No deep analysis or extensive verification.

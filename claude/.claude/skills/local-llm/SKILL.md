---
name: local-llm
description: Offload token-heavy work to a local ollama model via the `llm` script — pipe big content in and get only a short result back, or generate bulk output straight to a file — spending zero tokens from your own context/budget on the bulk. Use when about to Read or summarize a large log, build output, diff, or transcript (>~200 lines) where only the gist matters, or about to write >~100 lines of mechanical boilerplate/fixtures/test scaffolding; NOT when full-fidelity reading is load-bearing (subtle debugging, security review, multi-file reasoning), for small content (overhead exceeds savings), or when ~/.local/state/agents/local-llm.json says enabled:false.
---

Delegate bulk token work to the machine's local model through `llm`; keep the bulk out of your own context and output budget. The model has no tools and no repo access — it sees only stdin.

## 1. Capability gate + fallback
- Which model runs is per-machine; `llm` reads `~/.local/state/agents/local-llm.json` and announces any fallback on stderr. Calibrate trust to what answered — an 8B fallback gets simpler tasks than a 30B.
- **On ANY nonzero `llm` exit** (2 oversized · 3 server down · 4 disabled here · 5 no model · 6 API error · 124 timeout) → tell the user in one line why local delegation didn't happen, then do the task the normal way (yourself or the right subagent).
- Never start the server, never `ollama pull`. Both are the user's to run.

## 2. Shape — compress (best ROI)
- `producer-cmd | llm "instruction"` → only the short answer returns.
- **Never Read the big content first** — piping it in is the whole point; reading it first spends the tokens you meant to save.

## 3. Shape — generate
- `llm -o path "spec" [< context-file]` → bulk written to file, stdout is one receipt line.
- Then spot-check the file selectively — do not read it whole.

## 4. Rules
- Thinking is ON by default (keeps the answer clean — reasoning models otherwise leak reasoning prose into the output); pass `--no-think` only for speed on models known to stay clean without it.
- Input >~15k tokens → minutes of prefill; run via `run_in_background`.
- `--code` for codegen-shaped tasks (may resolve to the same model — the state file decides per machine).
- Local output is **advisory** — verify anything load-bearing yourself; never let it be final authority on correctness or security.

## 5. Templates
- Log-crunch → `tail -5000 build.log | llm "extract every error with file:line, dedupe, 10 bullets max"`
- Diff-summary → `git diff main... | llm "per-file: one line what changed and why it matters"`
- Test-scaffold → `llm --code -o tests/test_x.py "pytest scaffold for: <spec>" < src/x.py`
- Advisory-review → `llm "list suspicious spots with line numbers; flag, don't fix" < file`

## 6. Fit
- **Good** (by ROI): log/build/test-output crunching; long diff & git-history summarization; doc/transcript gisting; bulk boilerplate to file; test scaffolds; commit-message drafts from piped diffs; advisory single-file review.
- **Bad**: multi-file or cross-repo reasoning (model sees only stdin); architecture decisions; subtle debugging; content <~1–2KB; anything you must verify line-by-line anyway; final authority on correctness/security.

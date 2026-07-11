---
name: opencode-llm
description: Delegate a compress/generate micro-task to OpenCode CLI as an external text relay — `opencode-llm` runs a free-tier cloud model with no tools, mirroring `llm`'s stdin-in/short-answer-out contract. Use when about to offload a compress/generate micro-task and local ollama (`llm`) is disabled/unavailable or a stronger free model is wanted; NOT for tasks needing Claude's own judgment mid-task, anything touching the current working tree directly (use Claude's own tools or the Agent tool instead), or running under OpenCode itself (would mean OpenCode shelling out to itself).
---

Text-only relay wrapping the `opencode` CLI headlessly — the cloud-backed sibling of `llm` (`~/.claude/skills/local-llm` is the ollama analogue; the same fit-checklist applies, just cloud-backed). Prefer `llm` first (free, offline, zero external dependency); reach here when local delegation is disabled/unavailable or a stronger free model is wanted.

- Contract identical to `llm`: `producer-cmd | opencode-llm "instruction"` (compress) or `opencode-llm -o path "spec"` (generate, spot-check after).
- Backed by the `relay` agent (defined in `~/.config/opencode/opencode.json`): every tool denied, so it only ever answers from the text it's given — no file/repo/web access, nothing to verify beyond the text itself.
- Free-tier models only, ordered by preference in `opencode-models relay` (~2s fast, last-resort ~70-80s). `-m provider/model` forces one, skipping the fallback walk.
- **Always call via `run_in_background`** — even the fast path is seconds, not instant, and the slow fallback can be a minute-plus.
- On ANY nonzero exit (1 usage · 2 empty input · 3 opencode/jq missing · 5 no model available · 6 API error · 124 timeout) → one-line reason on stderr, then do the task the normal way (yourself or `llm` or the right subagent).
- Needs `opencode` CLI logged in already (`opencode auth login` / `opencode providers login`) — this script never authenticates.

## Fit
- **Good**: same ROI shape as `llm` (log/diff/doc gisting, boilerplate-to-file) when local ollama isn't an option, or a stronger free model is wanted.
- **Bad**: anything requiring Claude's own mid-task judgment or access to the current conversation's context; edits to the actual working tree (use Claude's own tools there); final authority on correctness/security for its output.

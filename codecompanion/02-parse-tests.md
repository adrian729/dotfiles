# Step 02 — Response parsing and its tests

**Goal** Turn an arbitrary agent reply into either code to place or a decision not to touch the buffer. This is the component that keeps prose, refusals and failed tool attempts out of source files.

**Files**

- `nvim/.config/nvim/lua/ai/inline/parse.lua`
- `nvim/.config/nvim/tests/parse_spec.lua`
- `nvim/.config/nvim/tests/fixtures/`

**Depends on** nothing. Buildable and testable before the pool exists, which is why it comes before inline proper.

**Evidence** `findings.md` → *Spike result*, behaviours 1–3 especially.

## Parsing order

1. If the reply contains a fenced block, extract the **first** fenced block and discard everything around it. Claude prefixes prose when tools are on; opencode has been seen fencing and not fencing across two runs days apart.
2. Otherwise treat the whole reply as code.
3. **Prose detection**: if the result doesn't look like code for the buffer's filetype, do not touch the buffer — hand it to the prose fallback.
4. **Tool-call-leak detection**: a reply containing `<tool_call>` / `<function=…>` markup is a failed tool attempt leaking as text, never code. Reject it the same way as prose.

Rule 4 is not hypothetical. Denying a tool an opencode model wanted produced exactly this, and it is a worse failure than tool use because it *looks* like output.

## Fixtures

Record real replies, not invented ones — the point is to pin behaviour that has already varied between agent versions. Six minimum:

| Fixture | Source | Expected |
|---|---|---|
| fenced with prose prefix | claude with tools on | code extracted, prose dropped |
| bare code, no fence | ollama cloud, opencode ACP first run | code as-is |
| fenced code, no prose | opencode ACP later run | code extracted |
| leaked `<tool_call>` XML | opencode under a full deny set | rejected as prose |
| refusal | claude asked to match a repo pattern with tools off | rejected as prose |
| question answered | claude asked "what does this do?" | rejected as prose |
| 57-line verbatim rename | any backend | byte-identical round trip |

`plenary.nvim` is already installed as a CodeCompanion dependency, so the runner is free.

## Done when

- every fixture parses to its expected outcome
- the verbatim rename fixture round-trips **byte-identically** — no trailing-newline drift, no tab-to-space conversion
- a reply that is only a fence with an empty body is treated as no-op, not as an empty edit that would delete the selection
- specs run green via plenary from a clean nvim

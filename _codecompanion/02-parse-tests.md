# Step 02 — Response parsing and its tests

**Goal** Turn an arbitrary agent reply into either code to place or a decision not to touch the buffer. This is the component that keeps prose, refusals and failed tool attempts out of source files.

**Files**

- `nvim/.config/nvim/lua/ai/inline/parse.lua`
- `nvim/.config/nvim/tests/parse_spec.lua`
- `nvim/.config/nvim/tests/fixtures/`

**Depends on** nothing. Buildable and testable before the pool exists, which is why it comes before inline proper.

**Evidence** `findings.md` → *Spike result*, behaviours 1–3 especially.

## Parsing order

1. **Tool-call-leak detection** runs first, on the text *outside* any fenced block: a reply carrying `<tool_call>` / `<function=` / `<parameter=` markup there is a failed tool attempt leaking as text, never code. Reject it the same way as prose.
2. If the reply contains a fenced block, extract the **first** fenced block and discard everything around it. Claude prefixes prose when tools are on; opencode has been seen fencing and not fencing across two runs days apart.
3. Otherwise treat the whole reply as code.
4. **Prose detection**: if the result doesn't look like code, do not touch the buffer — hand it to the prose fallback.

Rule 1 is not hypothetical. Denying a tool an opencode model wanted produced exactly this, and it is a worse failure than tool use because it *looks* like output. It is checked outside the fence rather than across the whole reply because the measured leak is unfenced message text, while a whole-reply search would reject legitimate code that merely contains the markup as a string — `parse.lua`'s own pattern list is exactly such a file. The tradeoff is that a leak the model chose to fence would slip through; no observed leak has been fenced.

Two cases the recorded replies added to the original list. An **unterminated fence** means a truncated reply: take everything after the opening fence rather than discarding it, and let prose detection decide. And a reply is code unless prose *wins* — fewer than half its non-blank lines looking like code — so an ambiguous one-liner is placed rather than refused.

## Fixtures

Record real replies, not invented ones — the point is to pin behaviour that has already varied between agent versions. Six minimum:

| Fixture | Source | Expected |
|---|---|---|
| `claude_fenced_prose.txt` | claude, asked to explain before the code | code extracted, prose dropped |
| `ollama_bare.txt` | ollama cloud `gpt-oss:120b` | code as-is, no fence |
| `claude_verbatim.txt` | claude, rename only | code extracted; byte-identical round trip |
| `opencode_fenced.txt` | opencode ACP | code extracted |
| `opencode_tool_call_leak.txt` | opencode under the relay's full deny set | rejected as prose |
| `claude_refusal.txt` | claude, asked to edit a function that is not there | rejected as prose |
| `claude_question.txt` | claude asked "what does this code do?" | rejected as prose |
| `_selection.txt` | not a reply — the 40 lines the others were asked to edit | the round-trip reference |

`plenary.nvim` is already installed as a CodeCompanion dependency, so the runner is free. `tests/minimal_init.lua` puts the config's own `lua/` and plenary on the runtimepath and nothing else.

Two notes from capturing these. The **refusal is harder to provoke than the spike suggested**: asked to "match the error-handling pattern used elsewhere in this repository" with no tools, claude simply made a reasonable change instead of refusing. It refuses reliably when the instruction names something that is not in the selection at all, which is what the recorded fixture does. And the recorded **opencode reply is a one-line fragment**, not the full selection — it ignored the reproduce-everything instruction. That parses correctly, but it is a prompt-design problem for step 03, not a parser problem.

## Done when

- every fixture parses to its expected outcome
- the verbatim rename fixture round-trips **byte-identically** — no trailing-newline drift, no tab-to-space conversion
- a reply that is only a fence with an empty body is treated as no-op, not as an empty edit that would delete the selection
- specs run green via plenary from a clean nvim — 15 of 15, `PlenaryBustedDirectory` with the minimal init

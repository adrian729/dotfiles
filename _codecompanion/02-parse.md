# Step 02 — Response parsing

**Goal** Turn an arbitrary agent reply into either code to place or a decision not to touch the buffer. This is the component that keeps prose, refusals and failed tool attempts out of source files.

**Files** `nvim/.config/nvim/lua/ai/inline/parse.lua`

**Depends on** nothing. Buildable before the pool exists, which is why it comes before inline proper.

**Evidence** `findings.md` → *Spike result*, behaviours 1–3 especially.

## Parsing order

1. **Tool-call-leak detection** runs first, on the text *outside* any fenced block: a reply carrying `<tool_call>` / `<function=` / `<parameter=` markup there is a failed tool attempt leaking as text, never code. Reject it the same way as prose.
2. If the reply contains a fenced block, extract the **first** fenced block and discard everything around it — but keep that prose as a `preamble`. Claude prefixes prose when tools are on; opencode has been seen fencing and not fencing across two runs days apart.
3. Otherwise treat the whole reply as code.
4. **Prose detection**: if the result doesn't look like code, do not touch the buffer — hand it to the prose fallback.

Rule 1 is not hypothetical. Denying a tool an opencode model wanted produced exactly this, and it is a worse failure than tool use because it *looks* like output. It is checked outside the fence rather than across the whole reply because the observed leak is unfenced message text, while a whole-reply search would reject legitimate code that merely contains the markup as a string — `parse.lua`'s own pattern list is exactly such a file. The tradeoff is that a leak the model chose to fence would slip through; no observed leak has been fenced.

Four cases that only showed up once real replies went through placement:

- **A trailing newline is not a trailing blank line.** Agents end replies with `\n`; taking that literally appends a blank line to the buffer on every single edit. Drop exactly one, so a reply that deliberately ends blank still gets it.
- **Keep the prose that surrounded the fence.** A model that declines usually echoes the selection back unchanged *and* explains itself around it. Discarding that leaves the user with a silent no-op and no reason for it — step 03 shows the preamble in the prose float when the reply turns out to change nothing.
- **An unterminated fence** means a truncated reply: take everything after the opening fence rather than discarding it, and let prose detection decide.
- A reply is code unless prose *wins* — fewer than half its non-blank lines looking like code — so an ambiguous one-liner is placed rather than refused.

## Behaviours worth knowing before writing the prompt

Two things measured while capturing real replies, both prompt-design input for step 03 rather than parser problems.

The **refusal is harder to provoke than the spike suggested**: asked to "match the error-handling pattern used elsewhere in this repository" with no tools, claude simply made a reasonable change instead of refusing. It refuses reliably when the instruction names something that is not in the selection at all. And **opencode returned a one-line fragment** instead of the full selection, ignoring the reproduce-everything instruction.

## Done when

Checked by hand against real replies from each backend, not by a suite:

- a fenced reply with a prose prefix places the code and drops the prose
- an unfenced reply places as-is
- a refusal, an answered question and a leaked `<tool_call>` reply all leave the buffer alone
- a rename round-trips **byte-identically** — no trailing-newline drift, no tab-to-space conversion
- a fence with an empty body is a no-op, not an empty edit that would delete the selection

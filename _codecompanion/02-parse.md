# Step 02 — Response parsing

**Goal** Turn an arbitrary agent reply into either code to place or a decision not to touch the buffer. This is the component that keeps prose, refusals and failed tool attempts out of source files.

**Files** `nvim/.config/nvim/lua/ai/inline/parse.lua`

**Depends on** nothing. Buildable before the pool exists, which is why it comes before inline proper.

**Evidence** `findings.md` → *Spike result*, behaviours 1–3 especially.

## Parsing order

1. **Tool-call-leak detection** runs first, on the text *outside* any fenced block: a reply carrying `<tool_call>` / `<function=` / `<parameter=` markup there is a failed tool attempt leaking as text, never code. Reject it the same way as prose.
2. If the reply contains a fenced block, extract the **first** fenced block and discard everything around it — but keep that prose as a `preamble`. Claude prefixes prose when tools are on; opencode has been seen fencing and not fencing across two runs days apart.
3. Otherwise treat the whole reply as code.
4. **Prose detection**: reject the reply only on *positive* evidence that it is not an edit. See below — this is the rule that matters most, and the obvious version of it is wrong.

Rule 1 is not hypothetical. Denying a tool an opencode model wanted produced exactly this, and it is a worse failure than tool use because it *looks* like output. It is checked outside the fence rather than across the whole reply because the observed leak is unfenced message text, while a whole-reply search would reject legitimate code that merely contains the markup as a string — `parse.lua`'s own pattern list is exactly such a file. The tradeoff is that a leak the model chose to fence would slip through; no observed leak has been fenced.

Four cases that only showed up once real replies went through placement:

- **A trailing newline is not a trailing blank line.** Agents end replies with `\n`; taking that literally appends a blank line to the buffer on every single edit. Drop exactly one, so a reply that deliberately ends blank still gets it.
- **Keep the prose that surrounded the fence, minus the lead-ins.** A model that declines usually echoes the selection back unchanged *and* explains itself around it, and step 03 shows that preamble when the reply turns out to change nothing. But "Here's the updated code:" is not an explanation, so content-free openers are stripped and a preamble made only of them is dropped — otherwise the float fires with nothing to say.
- **An unterminated fence** means a truncated reply: take everything after the opening fence rather than discarding it, and let prose detection decide.
- **A fence is the model saying "this part is code".** Take it at its word; never second-guess a fenced body.

## Prose must be proven, not inferred

The first version of this rule was *"a reply is code unless fewer than half its non-blank lines look like code"*, with "looks like code" meaning the line matched some pattern — braces, a call, an assignment, indentation. **That rule is wrong, and it was the single worst defect in the finished inline surface.** Most lines of most languages match no code pattern at all: `end`, `fi`, `FROM users`, `SELECT name, email`, `x`, `name: build`. Measured against a corpus of twenty replies — four of them captured live from ollama cloud — it misfiled nine as prose, including a correct SQL edit and a correct Markdown edit. The user's edit silently did not happen; they got a float instead.

The asymmetry the old rule got backwards: **a reply wrongly treated as code costs one keystroke.** It lands in a diff that has to be accepted, and `g3` puts the buffer back. A reply wrongly treated as prose costs the whole request — the edit does not happen and the user pays the model's latency again to retry. So the default for an unfenced reply is *code*, and prose needs evidence:

- **leaked tool markup** — always prose, in any filetype
- **an explicit refusal** — the first content line opens with one of a short closed list (`I can't`, `I cannot`, `Sorry`, `Unfortunately`, …) *and* every line reads as a sentence
- **an answer instead of an edit** — every line reads as a sentence, the reply reuses no line of the selection, *and* the buffer's filetype is one whose content is code

That last filetype condition is not a detail. In a Markdown, text, `gitcommit` or LaTeX buffer the correct replacement **is** a sentence, so a sentence test rejects every good reply. Those filetypes opt out of it entirely and rely on the first two signals.

"Reads as a sentence" is itself a positive test — four or more words, no code punctuation, no leading indentation, no comment marker, ending in sentence punctuation — never "did not match a code pattern". And the selection is passed in because the contract tells the model to reproduce unchanged lines exactly: a reply that shares a line with what it replaces is an edit, however little it looks like code on its own.

Two details of that test are load-bearing, and both were got wrong first:

- **Terminal punctuation is required of every line, the last one included.** Exempting the final line looks harmless — a refusal does not always end in a full stop — but for a *one-line* reply it removes the test's only remaining discriminator, and `SELECT id, email FROM users` becomes prose. A single-line reply is precisely where a sentence test has the least evidence, so it needs the most, not the least. Multi-line refusals are covered by the opener list instead, which does not require full sentences.
- **A comment marker makes a line code**, whatever else it looks like. A rewritten comment is the one edit that is genuinely both — `-- Returns the sum of the two arguments.` has four-plus words, no code punctuation and a full stop — and comment rewriting is a completely ordinary inline request. The list needs vimscript's `"` as well as the obvious `--`/`//`/`#`/`/*`/`%`; `;` needs no entry because the punctuation test already covers it.

Measured on the finished rule: **40 of 40** correct replies place, across lua, python, c, sql, sh, yaml, go, rust, html, css, json, make, vim, markdown, text, gitcommit, tex, conf, dockerfile and toml — one-liners, comment rewrites and prose-file edits included. **9 of 9** genuine refusals, answers and tool-call leaks still float.

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
- **bare code that matches no code pattern still places**: `end` on its own, `SELECT name, email` / `FROM users`, `set -eu` / `cd /tmp`, `name: build` / `on: push`
- **a prose file edits like any other**: a one-sentence rewrite in a Markdown, text or `gitcommit` buffer lands in the buffer, it does not float
- a preamble of only "Here's the updated code:" produces no float when the reply changes nothing — a notification is enough

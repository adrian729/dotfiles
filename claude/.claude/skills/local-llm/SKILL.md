---
name: local-llm
description: Offload bounded text summarization, extraction, or boilerplate generation to a local Ollama model through llm. Use when supplying the relevant text and verifying a compact result is useful; avoid tasks requiring ongoing repository exploration or the full conversation.
---

# Local Text Delegation

`llm` sends the prompt and stdin to Ollama without tools or repository access. It reads model preferences and the enabled flag from `~/.local/state/agents/local-llm.json`. The wrapper targets `localhost:11434`; it does not honor `OLLAMA_HOST`.

## Workflow

1. Choose a bounded task and supply its necessary context. Delegation is useful when it reduces the material you need to process or produces a verifiable draft. Prefer deterministic filtering when it already answers the question.
2. Pipe relevant content directly when you do not need to inspect it first. State the desired output and preserve source locations when they matter. If filtering or chunking, retain enough context for the requested coverage; a summary is not an exhaustive review.
3. Run `llm "instruction" < input` for a response, or `llm --code -o path "specification" < context` for a generated file. `--code` selects the configured code-model list. `-m MODEL` forces one model; `-T SECS` sets the request timeout (default 300).
4. Inspect the result to the extent correctness requires, including the whole input or output when necessary. Check important claims against source material and validate generated code. `-o` overwrites its destination: use a scratch file when replacing an existing file would lose work.
5. On failure, inspect stderr and choose an appropriate fallback. Oversized input may need narrower scope or chunks; disabled delegation, a missing model, or an unavailable server usually means completing the task directly. Preserve local-only requirements when choosing alternatives and report failures that affect the requested result.

The wrapper never starts Ollama or pulls models. Do not provision them merely for opportunistic delegation; use `ollama-cli` when setup is part of the request. For long calls, use the caller's supported background/polling mechanism when useful, with a bounded timeout.

```sh
llm "Extract errors with their source locations; group duplicates" < build.log
git diff --cached | llm "Draft a commit message for these staged changes"
```

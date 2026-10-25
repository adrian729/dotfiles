---
name: opencode-llm
description: Offload bounded text summarization or generation through OpenCode's cloud relay when local llm is unavailable or another model is useful. Use for supplied-text tasks, not repository editing or recursive delegation from inside OpenCode.
---

# OpenCode Text Relay

`opencode-llm` runs the `relay` agent in `~/.local/state/agents/opencode-llm-cwd`. It supplies the prompt and stdin, not the caller's conversation or project context. The configured relay denies every tool except `read`, which OpenCode's free tier requires; it also denies access outside that empty directory, and the wrapper itself does not disable every possible tool or provide a sandbox. Global configuration still applies.

## Workflow

1. Choose a task that can be answered from supplied text. Prefer an available local `llm` when it meets the task; use this relay when local inference is unavailable or the task benefits from another model. Preserve any local-only constraint.
2. Select a currently available free model unless explicitly asked to use paid models, including by an invoked workflow. For free selection, list free models with `opencode models opencode --verbose` and pick IDs whose `cost.input` and `cost.output` are 0. Pass the selected model with `-m` when the task requires a specific model rather than automatic fallback.
3. Supply relevant text and the required output. Use `-o path` for a file or stdout for a short response; `-T SECS` sets the per-request timeout (default 300). Use the caller's background/polling mechanism when useful rather than assuming a particular tool parameter.
4. Check exit status and stderr, then verify the response against the input. `-o` overwrites the destination; use a scratch file when replacing existing content would lose work. Validate generated code before integration.
5. On failure, complete the task directly or use another suitable model within the same constraints. Do not repeatedly retry unavailable models. The script requires existing OpenCode authentication and does not log in for you.

```sh
# Set delegate_model to the selected provider/model.
opencode-llm -m "$delegate_model" -- "Summarize errors with source locations" < build.log
opencode-llm -m "$delegate_model" -o draft.txt -- "SPECIFICATION" < context.txt
```

Without `-m`, the wrapper walks the zero-cost models in the live `opencode` catalog, moving to the next when one fails. Some free models reject the relay agent, so a fallback message on stderr is normal. Explicit `-m` bypasses this filter and disables fallback, so paid choices still require the instruction above.

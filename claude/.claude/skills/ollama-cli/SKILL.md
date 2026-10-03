---
name: ollama-cli
description: Run or manage Ollama models through the CLI or HTTP API. Use for direct inference, embeddings, server checks, and model management; use local-llm for the dotfiles text-offloading wrapper.
---

# Ollama CLI and API

## Workflow

1. Determine the intended server and model. The CLI uses `OLLAMA_HOST`, defaulting to `127.0.0.1:11434`. For HTTP requests, use that server's full URL, adding a scheme if needed. Check availability with `ollama list` or `GET /api/tags`; `ollama ps` lists loaded models.
2. Choose `ollama run` for simple prompt/stdin use, or the API for explicit request options and structured responses. Supply the needed content; ordinary generation has no access to the caller's conversation or repository tools.
3. For opportunistic offloading, use an available model and server. Do not start services or download models merely to make offloading possible. When setup or model installation is part of the requested task, `ollama serve` and `ollama pull MODEL` are appropriate. Verify locality when local-only inference matters; an Ollama endpoint can also serve cloud models.
4. Set output and context options to fit the task. `--format json` requests JSON output; parse and validate it. Thinking options depend on the model. The installed `ollama run --help` is the reference for supported flags; `--truncate` applies to embedding models, not text generation.
5. Check HTTP/process errors and completion before using the result. Validate generated code or consequential claims against the source. If a service is unavailable, follow the task's fallback constraints.

## Patterns

```sh
# Set ollama_model to an available model.
ollama run "$ollama_model" "Summarize the supplied log" < build.log
```

For API generation, `stream: false` returns one response object; the default streams partial responses. Construct JSON with a serializer so input quotes and newlines are preserved. This Bash example uses an explicit server URL and propagates pipeline failures:

```bash
set -o pipefail
ollama_url=http://127.0.0.1:11434  # Use the intended server's full URL.
jq -n --arg model "$ollama_model" --rawfile content build.log \
  '{model:$model, prompt:("Summarize this log:\n\n" + $content), stream:false}' |
  curl --fail-with-body --silent --show-error --max-time 300 \
    -H 'Content-Type: application/json' --data-binary @- \
    "$ollama_url/api/generate" |
  jq -er 'select(.done == true and .error == null) | .response'
```

For other operations, consult the relevant endpoint: [generate](https://docs.ollama.com/api/generate) takes `prompt`, [chat](https://docs.ollama.com/api/chat) takes a `messages` array, and [embed](https://docs.ollama.com/api/embed) takes `input` and returns `embeddings`. Use the API's `options` object for generation parameters rather than inventing CLI flags. Use `ollama COMMAND --help` for model management.

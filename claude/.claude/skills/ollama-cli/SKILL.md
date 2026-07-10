---
name: ollama-cli
description: Invoke the Ollama CLI or REST API from any tool — subcommands (serve, run, pull, push, list, ps, show, create, cp, rm, stop), run flags (`--format json`, `--keepalive`, `--verbose`, think mode), REST API endpoints (`/api/generate`, `/api/chat`, `/api/embeddings`, `/api/tags`, `/api/version`), env vars (`OLLAMA_HOST`, `OLLAMA_MODELS`, `OLLAMA_NUM_PARALLEL`). Use when the caller needs to run, query, or manage Ollama models from a script, pipe, HTTP client, or another AI tool; NOT for configuring the ollama server's system-level settings (handle those via env vars in `ollama.env`)
---

Ollama — local LLM runner. Two interfaces: CLI binary and REST API at `OLLAMA_HOST` (default `127.0.0.1:11434`). Use the REST API when calling from another tool within the same machine; use the CLI in interactive/terminal contexts.

## Subcommands

| Command                       | Description                                               |
| ----------------------------- | --------------------------------------------------------- |
| `ollama serve`                | Start the Ollama server daemon                            |
| `ollama run <model> [prompt]` | Run a model (interactive or one-shot)                     |
| `ollama pull <model>`         | Download a model from registry                            |
| `ollama push <model>`         | Upload a model to registry                                |
| `ollama list` / `ls`          | List downloaded models                                    |
| `ollama ps`                   | List currently loaded/running models                      |
| `ollama show <model>`         | Show model details (modelfile, params, license, template) |
| `ollama create <model>`       | Create a model from a Modelfile                           |
| `ollama cp <src> <dest>`      | Copy a model                                              |
| `ollama rm <model...>`        | Remove one or more models                                 |
| `ollama stop <model>`         | Unload a model from memory                                |
| `ollama signin`               | Sign in to ollama.com                                     |
| `ollama signout`              | Sign out from ollama.com                                  |

## `ollama run` flags

| Flag                     | Description                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------- |
| `--format json`          | Return response as JSON                                                                        |
| `--keepalive <duration>` | Keep model loaded after request (e.g. `5m`, `30m`, `-1m` for indefinite)                       |
| `--verbose`              | Show timing statistics                                                                         |
| `--nowordwrap`           | Don't wrap words to next line                                                                  |
| `--insecure`             | Use an insecure registry                                                                       |
| `--think [bool\|level]`  | Enable thinking mode: `true`/`false` or `high`/`medium`/`low`                                  |
| `--hidethinking`         | Hide thinking output (if model provides it)                                                    |
| `--dimensions <n>`       | Truncate output embeddings to N dimensions (embedding models only)                             |
| `--truncate [bool]`      | Truncate inputs exceeding context length (default `true`); `--truncate=false` to error instead |

Image generation (experimental): `--width`, `--height`, `--steps`, `--seed`, `--negative <str>`

Experimental agent: `--experimental` (agent loop with tools), `--experimental-websearch`, `--experimental-yolo` (skip tool approval).

## Model management workflow

```sh
# Pull a model
ollama pull llama3.2
ollama pull qwen3:14b

# List what's available
ollama list

# Check what's loaded in memory
ollama ps

# Show model info
ollama show qwen3:14b
ollama show qwen3:14b --modelfile
ollama show qwen3:14b --parameters
ollama show qwen3:14b --license
ollama show qwen3:14b --system

# Run one-shot with a prompt
ollama run qwen3:14b "What is the capital of France?"

# Run with JSON output
ollama run qwen3:14b --format json "List 3 colors" | jq .

# Create a custom model from a Modelfile
ollama create my-model -f ./Modelfile

# Copy and remove
ollama cp my-model my-model-backup
ollama rm my-model-backup

# Unload a model from memory
ollama stop qwen3:14b
```

## Piping patterns

Raw piping examples below show the mechanics, along with the pull/server-start caution these raw examples don't cover.

```sh
# Pipe content as prompt context
echo "The sky is blue because..." | ollama run qwen3:14b "Summarize in one sentence"

# Pipe file content
cat build.log | ollama run qwen3:14b "Extract all error lines"

# Diff summarization
git diff | ollama run qwen3:14b "Write a short commit message"

# Keep model loaded between calls (avoids reload latency)
ollama run qwen3:14b --keepalive 30m "First query"
ollama run qwen3:14b --keepalive 30m "Second query (faster)"
```

## REST API

Base URL: `$OLLAMA_HOST` (default `http://127.0.0.1:11434`)

### Generate (one-shot text completion)

```
POST /api/generate
```

```json
{
  "model": "qwen3:14b",
  "prompt": "Why is the sky blue?",
  "stream": false,
  "options": {
    "num_ctx": 32768,
    "temperature": 0.7
  }
}
```

```sh
curl -X POST http://localhost:11434/api/generate \
  -d '{"model":"qwen3:14b","prompt":"Why is the sky blue?","stream":false}' | jq .response
```

### Chat (multi-turn)

```
POST /api/chat
```

```json
{
  "model": "qwen3:14b",
  "messages": [{ "role": "user", "content": "Why is the sky blue?" }],
  "stream": false
}
```

### Embeddings

```
POST /api/embeddings
```

```json
{
  "model": "nomic-embed-text",
  "prompt": "The sky is blue"
}
```

### List models

```
GET /api/tags
```

```sh
curl http://localhost:11434/api/tags | jq '.models[].name'
```

### Show model details

```
POST /api/show
{"model": "qwen3:14b"}
```

### Server health

```
GET /api/version
```

```sh
curl -sf http://localhost:11434/api/version
```

### Pull a model

```
POST /api/pull
{"model": "llama3.2", "stream": false}
```

### Check running models

```
GET /api/ps
```

## Key environment variables

| Variable                   | Default            | Description                                           |
| -------------------------- | ------------------ | ----------------------------------------------------- |
| `OLLAMA_HOST`              | `127.0.0.1:11434`  | Server address (CLI + API)                            |
| `OLLAMA_MODELS`            | platform-specific  | Models directory path                                 |
| `OLLAMA_DEBUG`             | off                | Show debug information                                |
| `OLLAMA_CONTEXT_LENGTH`    | auto (4k/32k/256k) | Default context window                                |
| `OLLAMA_KEEP_ALIVE`        | `5m`               | Duration models stay loaded in memory                 |
| `OLLAMA_NUM_PARALLEL`      | 1                  | Max parallel requests                                 |
| `OLLAMA_MAX_LOADED_MODELS` | auto               | Max loaded models per GPU                             |
| `OLLAMA_FLASH_ATTENTION`   | off                | Enable flash attention                                |
| `OLLAMA_KV_CACHE_TYPE`     | `f16`              | K/V cache quantization                                |
| `OLLAMA_NO_CLOUD`          | off                | Disable cloud features (remote inference, web search) |
| `OLLAMA_MAX_QUEUE`         | auto               | Max queued requests                                   |
| `OLLAMA_LOAD_TIMEOUT`      | `5m`               | Max wait for model load                               |
| `OLLAMA_NOPRUNE`           | off                | Skip blob pruning on startup                          |
| `OLLAMA_SCHED_SPREAD`      | off                | Schedule model across all GPUs                        |
| `OLLAMA_GPU_OVERHEAD`      | 0                  | Reserve VRAM per GPU (bytes)                          |
| `OLLAMA_ORIGINS`           | `[localhost]`      | Allowed CORS origins                                  |
| `OLLAMA_LLM_LIBRARY`       | auto               | Force specific LLM library                            |
| `OLLAMA_API_KEY`           | none               | Auth key for remote Ollama instances                  |

## Config

Ollama loads no config file by default. The dotfiles repo sources `~/.config/ollama/ollama.env` at shell startup to set environment variables:

```sh
# ~/.config/ollama/ollama.env
export OLLAMA_API_KEY=sk-...
# export OLLAMA_HOST=10.0.0.1:11434
```

## Scripting patterns

```sh
# Check if server is running
curl -sf http://localhost:11434/api/version >/dev/null && echo "up" || echo "down"

# One-shot with specific context length and temperature
ollama run qwen3:14b --format json "Solve: 2+2"

# Via REST API (no binary dependency)
curl -s http://localhost:11434/api/generate \
  -d '{"model":"qwen3:14b","prompt":"Summarize","stream":false}' | jq -r '.response'

# Pipe stdin to API
cat file.txt | jq -Rs '{model:"qwen3:14b",prompt:.,stream:false}' | \
  curl -s -X POST -H "Content-Type: application/json" -d @- \
  http://localhost:11434/api/generate | jq -r '.response'

# Pull model non-interactively
ollama pull llama3.2

# List models as JSON (ollama list has no --format flag; the API returns JSON natively)
curl -s http://localhost:11434/api/tags | jq '.models[].name'

# List models, plain text (non-JSON)
ollama list

# Keep a model warm in memory
ollama run qwen3:14b --keepalive -1m "ping"

# Loaded models in memory
ollama ps
curl -s http://localhost:11434/api/ps | jq '.models[].name'
```

# Machine-readable model reference for OpenCode Zen, Go, and Ollama Cloud. Fields only — no prose, no descriptions, no human-aimed text. Edit data only.

Verified 2026-09-26 against opencode.ai/docs/zen + opencode.ai/docs/go (both last updated 2026-09-25) and models.dev/api.json. Live availability is ground truth for which models exist: `opencode models <provider>`.

## Rules for editing this file + opencode-models.json

- Every model name is fully provider-prefixed: `opencode-go/` (Go), `opencode/` (free tier), `ollama-cloud/` (Ollama Cloud). Never bare, never `-cloud` suffix shorthand.
- Specs always inlined per model; never cross-reference another section ("same as Go entry"). LLM readers must not chase pointers — duplicate specs where models overlap providers (Ollama Cloud overlapping section).
- Agent-to-model mapping: the model lists live in `opencode-models.json`. This document's Agent section only describes agent purpose + JSON format constraints (max 10, sorted by fit, prefix rule). When syncing after model availability changes, update both files.
- `opencode-models.json` free_models: only models that `opencode-models free` should return, and only ones `opencode models opencode` actually lists. relay: ordered fallback walk over free_models for `opencode-llm` — it is NOT a verified-usable subset, only `opencode/space-bunny-free` has been observed to complete under the relay agent's no-tools config (see "Relay-agent compatibility"); keep the verified model first. agents: ranked preference lists, first available free model auto-selected by probe.
- `ollama-cloud/` is absent from free_models and every agent list: the provider needs `OLLAMA_API_KEY` and is not connected on this machine, so the probe cannot see it. Re-add after `/connect` if wanted. `model-fallback.js` still filters the prefix out of the fallback path.
- Mo limit: the Go plan's per-model monthly dollar limit, verbatim from opencode.ai/docs/go. It is NOT one global figure — it is $60, $30, or $15 depending on the model.
- Context/Output figures are rounded for reading, never claimed exact. models.dev reports two families of integers for what vendors all market as the same size — some declare 1000000/1050000/500000 (decimal), others 1048576/262144/131072 (binary). A figure within 5% of a familiar label (1M, 512K, 256K, 128K, 64K, 32K) is written as that label; anything else is floored to 2 significant figures (202K, 976K). So `1M` may be 1000000, 1024000 or 1048576, and `256K` may be 256000 or 262144. models.dev/api.json is the exact source; treat these as tier labels, and do not "correct" one label into another.
- Req/mo: sourced verbatim from that page's "Estimated requests" table, not derived. The same table also publishes Req/5h and Req/wk, but only Req/mo is recorded here — it alone drives Go rank and Avg $/session, so the other two are redundant for every decision this file supports. Cache %: cached/(cached+input), computed from the same page's published per-request token-pattern figures. Go rank: models ranked by Req/mo, descending (#1 = highest).
- Avg $/session: (that model's own Mo limit ÷ Req/mo) × 20 requests — 20 is a fixed session-length assumption (this machine's own `opencode stats` average), not a vendor-reported figure.
- Context/Output limits and input modalities come from models.dev/api.json, not the docs pages (the docs publish no context figures).

## Limits

Go is a $10/month subscription. Usage limits are per-model monthly dollar amounts; each model's 5-hour window is 20% of its Mo limit and its weekly window is 50%. Example: a $60-limit model allows $12 per 5h, $30 per week, $60 per month. Free models are unlimited and do not count. Past a model's limit, enable "Use balance" in the console to fall through to Zen credits.

## Go models

Model: opencode-go/space-bunny-free
Mo limit: free (unlimited)
Avg $/session: $0
Context: 1M | Output: 512K
Input: text+image+video
Cache: n/a | Go rank: unlimited
Req/mo: unlimited
Use: free and unlimited on Go, 1M context, 512K output, multimodal
Skip: quality unproven (stealth model); trains on nothing and retains 0 days, but so do most Go models — only the two Muse Spark Contributor tiers train. Free-and-unlimited is the actual differentiator, not the privacy.

Model: opencode-go/muse-spark-1.3-contributor
Cost in/out/cached: $0.10 / $0.20 / $0.002
Mo limit: $60
Avg $/session: $0.01
Context: 1M | Output: 128K
Input: text+image+video+pdf+audio
Cache: 99% | Go rank: #1
Req/mo: 226.6K
Use: highest-volume cheapest sessions, full multimodal coding workflows, complex debugging
Skip: region-limited (Meta geographic policy), trains on your prompts

Model: opencode-go/muse-spark-1.2-contributor
Cost in/out/cached: $0.10 / $0.20 / $0.002
Mo limit: $60
Avg $/session: $0.01
Context: 1M | Output: 128K
Input: text+image+video+pdf+audio
Cache: 99% | Go rank: #2
Req/mo: 226.6K
Use: same price/volume/spec as 1.3, wider region availability
Skip: superseded by 1.3 unless 1.3 is region-blocked

Model: opencode-go/mimo-v2.6-flash
Cost in/out/cached: $0.14 / $0.28 / $0.0028
Mo limit: $60
Avg $/session: $0.01
Context: 1M | Output: 128K
Input: text+image+audio+video
Cache: 99% | Go rank: #3
Req/mo: 150.4K
Use: highest volume after Muse Spark, only Go model taking audio, vision, video
Skip: deep reasoning

Model: opencode-go/mimo-v2.5
Cost in/out/cached: $0.14 / $0.28 / $0.0028
Mo limit: $60
Avg $/session: $0.01
Context: 1M | Output: 128K
Input: text+image+audio+video
Cache: 99% | Go rank: #4
Req/mo: 150.4K
Use: same price as V2.6 Flash
Skip: V2.6 Flash is newer at the same price

Model: opencode-go/deepseek-v4.1-flash
Cost in/out/cached: $0.15 / $0.60 / $0.003 (off-peak); $0.30 / $1.20 / $0.006 (peak)
Mo limit: $60
Avg $/session: $0.01
Context: 1M | Output: 384K
Input: text+image
Cache: 99% | Go rank: #5
Req/mo: 130K
Use: best value per dollar with 384K output, vision, high volume
Skip: peak-hour price doubles

Model: opencode-go/deepseek-v4-flash
Cost in/out/cached: $0.15 / $0.60 / $0.003 (off-peak); $0.30 / $1.20 / $0.006 (peak)
Mo limit: $30
Avg $/session: $0.01
Context: 1M | Output: 384K
Input: text
Cache: 99% | Go rank: #6
Req/mo: 65K
Use: daily coding, boilerplate, prototyping, iterative edits
Skip: vision (use V4.1 Flash), $30 limit halves volume vs V4.1

Model: opencode-go/longcat-2.0
Cost in/out/cached: $0.30 / $1.20 / $0.006
Mo limit: $60
Avg $/session: $0.02
Context: 1M | Output: 128K
Input: text
Cache: 99% | Go rank: #7
Req/mo: 57.2K
Use: Meituan reasoning model, 1M context, tool calling, cheap, high volume
Skip: needing wide ecosystem/track record (newest family on Go)

Model: opencode-go/deepseek-v4-flash-vision-exp
Cost in/out/cached: $0.15 / $0.60 / $0.003 (off-peak); $0.30 / $1.20 / $0.006 (peak)
Mo limit: $15
Avg $/session: $0.01
Context: 1M | Output: 384K
Input: text+image
Cache: 99% | Go rank: #8
Req/mo: 32.5K
Use: image-in-the-loop coding, screenshot/diagram review
Skip: V4.1 Flash does the same for 4x the volume; experimental; images billed as input tokens

Model: opencode-go/glm-5.3-flash
Cost in/out/cached: $0.15 / $0.50 / $0.03
Mo limit: $60
Avg $/session: $0.04
Context: 1M | Output: 128K
Input: text+image+video+pdf
Cache: 98% | Go rank: #9
Req/mo: 31.58K
Use: cheapest GLM tier, native multimodal (image/video/PDF), efficient coding and long-horizon agent tasks
Skip: budget-critical volume (higher rank tier models go further per dollar)

Model: opencode-go/qwen3.8-flash
Cost in/out/cached: $0.15 / $0.47 / $0.016 | cached write: $0.20
Mo limit: $30
Avg $/session: $0.02
Context: 1M | Output: 128K
Input: text+image+video
Cache: 99% | Go rank: #10
Req/mo: 27K
Use: best value new mid-tier, vision, video, replaces 3.7 Plus at a lower price
Skip: tasks specifically needing 3.7 Plus/Max's output ceiling

Model: opencode-go/qwen3.7-plus
Cost in/out/cached: $0.40 / $1.60 / $0.04 | cached write: $0.50 (≤256K); $1.20 / $4.80 / $0.12 | cached write: $1.50 (>256K)
Mo limit: $60
Avg $/session: $0.06
Context: 1M | Output: 64K
Input: text+image+video
Cache: 99% | Go rank: #11
Req/mo: 21.6K
Use: mid-tier reasoning, vision, video
Skip: tasks fully within 256K context on a budget (3.8 Flash is cheaper)

Model: opencode-go/hy3
Cost in/out/cached: $0.14 / $0.58 / $0.035
Mo limit: $60
Avg $/session: $0.06
Context: 256K | Output: 128K
Input: text
Cache: 99% | Go rank: #12
Req/mo: 21.5K
Use: Tencent open-weight model, cheap input, good cache ratio
Skip: tasks needing >256K context, vision/video/audio

Model: opencode-go/gpt-6-luna
Cost in/out/cached: $0.10 / $0.50 / $0.01 | cached write: $0.125 (≤272K); $0.20 / $0.75 / $0.02 | cached write: $0.25 (>272K)
Mo limit: $15
Avg $/session: $0.01
Context: 1M | Output: 128K
Input: text+image+pdf
Cache: 98% | Go rank: #13
Req/mo: 21.13K
Use: cheapest GPT-6 class, vision, PDF, strongest reasoning per dollar on Go
Skip: $15 limit is the tightest tier

Model: opencode-go/minimax-m2.7
Cost in/out/cached: $0.30 / $1.20 / $0.06 | cached write: $0.375
Mo limit: $60
Avg $/session: $0.07
Context: 204K | Output: 128K
Input: text
Cache: 99% | Go rank: #14
Req/mo: 17K
Use: cheap MiniMax sessions at 205K context
Skip: tasks needing >205K context, M3 is better

Model: opencode-go/mimo-v2.6-pro
Cost in/out/cached: $0.435 / $0.87 / $0.003625
Mo limit: $15
Avg $/session: $0.02
Context: 1M | Output: 128K
Input: text+image+audio+video
Cache: 99% | Go rank: #15
Req/mo: 16.3K
Use: reasoning with Xiaomi approach, multimodal
Skip: $15 limit; unless you specifically prefer Xiaomi over DeepSeek

Model: opencode-go/qwen3.6-plus
Cost in/out/cached: $0.50 / $3.00 / $0.05 | cached write: $0.625 (≤256K); $2.00 / $6.00 / $0.20 | cached write: $2.50 (>256K)
Mo limit: $60
Avg $/session: $0.07
Context: 1M | Output: 64K
Input: text+image+video
Cache: 99% | Go rank: #16
Req/mo: 16.3K
Use: vision+video tasks
Skip: text-only work (3.7 Plus same price, newer)

Model: opencode-go/mimo-v2.5-pro
Cost in/out/cached: $0.435 / $0.87 / $0.003625
Mo limit: $15
Avg $/session: $0.02
Context: 1M | Output: 128K
Input: text
Cache: 99% | Go rank: #17
Req/mo: 16.3K
Use: text-only Xiaomi reasoning
Skip: superseded by V2.6 Pro

Model: opencode-go/minimax-m3
Cost in/out/cached: $0.30 / $1.20 / $0.06
Mo limit: $60
Avg $/session: $0.08
Context: 1M | Output: 128K
Input: text+image+video
Cache: 99% | Go rank: #18
Req/mo: 16K
Use: efficient mid-tier coding, balanced cost-performance, vision/video
Skip: not cheapest at this volume (Hy3/Qwen3.7 Plus are)

Model: opencode-go/gpt-5.6-luna
Cost in/out/cached: $0.20 / $1.20 / $0.02 | cached write: $0.25 (≤272K); $0.40 / $1.80 / $0.04 | cached write: $0.50 (>272K)
Mo limit: $15
Avg $/session: $0.03
Context: 1M | Output: 128K
Input: text+image+pdf
Cache: 98% | Go rank: #19
Req/mo: 10.25K
Use: GPT-5 class reasoning, vision, PDF
Skip: GPT 6 Luna is cheaper and newer at half the session cost

Model: opencode-go/hy4-preview
Cost in/out/cached: $0.834 / $2.501 / $0.042
Mo limit: $30
Avg $/session: $0.09
Context: 1M | Output: 64K
Input: text
Cache: 99% | Go rank: #20
Req/mo: 6.77K
Use: newer Tencent Hy preview, stronger agent workflows and complex task execution
Skip: preview status — Hy3 is cheaper and more established for routine work

Model: opencode-go/kimi-k2.7-code
Cost in/out/cached: $0.95 / $4.00 / $0.19
Mo limit: $60
Avg $/session: $0.18
Context: 256K | Output: 256K
Input: text+image+video
Cache: 98% | Go rank: #21
Req/mo: 6.75K
Use: large code generation, 262K output, vision
Skip: short tasks (expensive per session)

Model: opencode-go/kimi-k2.6
Cost in/out/cached: $0.95 / $4.00 / $0.16
Mo limit: $60
Avg $/session: $0.21
Context: 256K | Output: 64K
Input: text+image+video
Cache: 98% | Go rank: #22
Req/mo: 5.75K
Use: general tasks needing vision+video
Skip: large output (use K2.7 Code), coding-specific (K2.7 Code better)

Model: opencode-go/deepseek-v4-pro
Cost in/out/cached: $0.66 / $1.98 / $0.022 (off-peak); $1.32 / $3.96 / $0.044 (peak)
Mo limit: $15
Avg $/session: $0.06
Context: 1M | Output: 384K
Input: text
Cache: 99% | Go rank: #23
Req/mo: 5.2K
Use: complex refactors, multi-step reasoning, code review
Skip: $15 limit, doubles at peak

Model: opencode-go/glm-5.2
Cost in/out/cached: $1.40 / $4.40 / $0.26
Mo limit: $60
Avg $/session: $0.28
Context: 1M | Output: 128K
Input: text
Cache: 99% | Go rank: #24
Req/mo: 4.3K
Use: Chinese codebases, bilingual CN/EN docs, Chinese dev conventions, open-weight flagship
Skip: English-only work (too expensive for what you get)

Model: opencode-go/glm-5.1
Cost in/out/cached: $1.40 / $4.40 / $0.26
Mo limit: $60
Avg $/session: $0.28
Context: 202K | Output: 32K
Input: text
Cache: 99% | Go rank: #25
Req/mo: 4.3K
Use: same as 5.2 but less context needed, tighter output
Skip: 5.2 is better if you have the context

Model: opencode-go/glm-5.3
Cost in/out/cached: $1.40 / $4.40 / $0.26
Mo limit: $15
Avg $/session: $0.28
Context: 1M | Output: 128K
Input: text
Cache: 99% | Go rank: #26
Req/mo: 1.08K
Use: latest GLM flagship, finest-grained effort control (low/high/max), long-horizon coding and complex project delivery
Skip: $15 limit; not open-weight (closed) — 5.2 is the open-weight flagship at the same price

Model: opencode-go/grok-4.7
Cost in/out/cached: $2.00 / $6.00 / $0.50 (≤200K); $4.00 / $12.00 / $1.00 (>200K)
Mo limit: $15
Avg $/session: $0.36
Context: 512K | Output: 512K
Input: text+image+pdf
Cache: 99% | Go rank: #27
Req/mo: 845
Use: massive output (500K), vision, PDF, large reasoning windows
Skip: $15 limit, premium tier over 200K

Model: opencode-go/grok-4.6
Cost in/out/cached: $2.00 / $6.00 / $0.50 (≤200K); $4.00 / $12.00 / $1.00 (>200K)
Mo limit: $15
Avg $/session: $0.36
Context: 512K | Output: 512K
Input: text+image
Cache: 99% | Go rank: #28
Req/mo: 845
Use: same as 4.7 minus PDF
Skip: 4.7 is newer at the same price

Model: opencode-go/qwen3.7-max
Cost in/out/cached: $2.50 / $7.50 / $0.50 | cached write: $3.125
Mo limit: $30
Avg $/session: $0.71
Context: 1M | Output: 64K
Input: text
Cache: 99% | Go rank: #29
Req/mo: 840
Use: hardest problems, architecture design, complex debugging
Skip: everyday tasks (limit gone in days); 3.8 Max is stronger for less

Model: opencode-go/qwen3.8-max
Cost in/out/cached: $2.00 / $6.00 / $0.25 | cached write: $2.50
Mo limit: $15
Avg $/session: $0.37
Context: 1M | Output: 128K
Input: text+image+video
Cache: 99% | Go rank: #30
Req/mo: 810
Use: newest Qwen flagship, hardest problems, vision/video
Skip: $15 limit, 2nd-lowest Req/mo of any priced Go model (only kimi-k3 is lower)

Model: opencode-go/kimi-k3
Cost in/out/cached: $3.00 / $15.00 / $0.30
Mo limit: $15
Avg $/session: $0.61
Context: 1M | Output: 128K
Input: text+image+video
Cache: 99% | Go rank: #31
Req/mo: 490
Use: frontier Kimi reasoning, 1M context
Skip: budget sessions (lowest Req/mo on Go, most expensive output)

## Go peak hours

DeepSeek V4.1 Flash / V4 Pro / V4 Flash / V4 Flash Vision Exp bill at two rates. Peak = 01:00-04:00 and 06:00-10:00 UTC, Monday-Friday. All other hours, including weekends, are off-peak.

## Go privacy

Model training / retention, from opencode.ai/docs/go:

Retention 0 days, not used for training: longcat-2.0, all GLM, all Kimi, all MiniMax, all MiMo, all Qwen, DeepSeek V4 family (ZDR agreement renewed monthly, valid through 2026-09-30), Hy3, Hy4 preview, Space Bunny Free.
Retention 30 days, not used for training: grok-4.6, grok-4.7, gpt-5.6-luna, gpt-6-luna (abuse monitoring logs).
Not ZDR, trains on your prompts: muse-spark-1.2-contributor, muse-spark-1.3-contributor (Meta; also region-limited by Meta's Geographic Use Policy).

## Relay walk (opencode-llm)

`opencode-llm` reads its candidate list from `~/.local/state/agents/opencode-llm.json` (written by `opencode-llm-probe`) and only falls back to `opencode-models.json`'s `relay` key when that state file is absent or empty. So editing `relay` in the config does **not** take effect until `opencode-llm-probe` re-runs — `install.sh` does this, but a hand-edit of the config alone is silently shadowed by the previous run's state file. Re-run the probe after any `relay` reorder.

## Free models

All free models cost $0; the Zen page describes each as free for a limited time while the team collects feedback. Availability is exactly what `opencode models opencode` returns. Data-use policy per model, from opencode.ai/docs/zen.

Model: opencode/muse-spark-1.3-contributor-free
Context: 1M | Output: 128K
Input: text+image+video+pdf+audio
Privacy: prompts/completions used to train future Meta models, in exchange for the discount
Note: Meta-hosted, coding-focused, the free tier of the Muse Spark 1.3 Contributor variant; the 1.2 Contributor free variant is no longer offered

Model: opencode/space-bunny-free
Context: 1M | Output: 512K
Input: text+image+video
Privacy: zero-retention, provider does not use your data for model training
Note: stealth model; also free and unlimited on opencode-go/; largest free context+output, only free model with clean privacy

Model: opencode/mimo-v2.6-flash-free
Context: 200K | Output: 32K
Input: text+image+audio+video
Privacy: data may be used to improve the model (free period)
Note: free tier of the same model sold paid on Go as opencode-go/mimo-v2.6-flash; free for a limited time, not a per-request rate limit. mimo-v2.5-free is the same deal one version back and is no longer in the CLI catalog

Model: opencode/big-pickle
Context: 200K | Output: 32K
Input: text
Privacy: data may be used to improve the model (free period)
Note: stealth model, unknown origin, experimental

Model: opencode/nemotron-3.5-lightning-free
Context: 256K | Output: 256K
Input: text
Privacy: NVIDIA trial — logged for security/product improvement, not linked to identity
Note: NVIDIA-hosted, fast Nemotron MoE, 256K output on a free model

Model: opencode/nemotron-3-ultra-free
Context: 1M | Output: 128K
Input: text
Privacy: NVIDIA trial — logged for security/product improvement, not linked to identity
Note: NVIDIA-hosted, 1M context

Model: opencode/ling-3.0-flash-fin-free
Context: 256K | Output: 32K
Input: text
Privacy: data may be used to improve the model (free period)
Note: finance-enhanced variant; no plain ling-3.0-flash-free is listed on the Zen page and the Zen deprecation table does not name it

### Relay-agent compatibility (observed 2026-09-26)

`opencode-llm-probe` only checks that a relay model is *listed*; it cannot check that it *works*. Sending a real request through `--agent relay` (every tool denied) on 2026-09-26: of the 7 free models above, only `opencode/space-bunny-free` completed. The other 6 — muse-spark-1.3-contributor-free, mimo-v2.6-flash-free, big-pickle, nemotron-3.5-lightning-free, nemotron-3-ultra-free, ling-3.0-flash-fin-free — all returned APIError "OpenCode's free tier can only be used from within OpenCode", reproducibly, while the same models served `implementer`/`researcher`/`task`/etc. without error. The error text does not name a cause; the split does not track modality, context size, or the Zen endpoint/SDK each model uses (big-pickle and space-bunny-free share `chat/completions` + `@ai-sdk/openai-compatible` yet differ). Treat as relay-specific, re-test before reordering: `opencode/space-bunny-free` is first in `relay` for that reason. Because `relay` is a walk-not-a-pin list, a regression here costs a wasted round trip per call rather than a hard failure — but put the working model first anyway.

### Free models documented but NOT listed by the CLI

Do not put these in free_models — `opencode models opencode` does not return them.

Model: opencode/mimo-v2.5-free
Context: 200K | Output: 32K
Input: text+image+audio+video
Note: still on the Zen pricing page, one version behind mimo-v2.6-flash-free, absent from the CLI catalog

Model: opencode/jev-1.13-free
Note: NOT a chat model. Jev is a System One endpoint (https://opencode.ai/zen/v1/systemone) that evaluates a state against typed questions and returns values+probabilities. Unusable as an agent or relay model.

## Ollama Cloud (NOT CONNECTED on this machine)

Provider `ollama-cloud` still exists upstream (24 models in models.dev) but requires `OLLAMA_API_KEY`; it is absent from this machine's `opencode models` output, so no ollama-cloud entry appears in `opencode-models.json`. Reconnect with `/connect` and re-add to free_models/agents to use.
Free tier: light GPU-time usage, 1 concurrent model. Usage levels Low/Medium/High/Extra High set GPU-time cost per request.
Overlapping models (same model as Go entries) have separate limits per provider. Ollama Cloud specs often allow far more output than Go.

### Unique to Ollama Cloud

Model: ollama-cloud/gpt-oss:20b
Context: 128K | Output: 32K
Input: text
Capabilities: tools, thinking
Note: OpenAI open-weight, Apache 2.0

Model: ollama-cloud/gpt-oss:120b
Context: 128K | Output: 32K
Input: text
Capabilities: tools, thinking
Note: larger variant

Model: ollama-cloud/gemma4:31b
Context: 256K | Output: 256K
Input: text+image
Capabilities: vision, tools, thinking
Note: Google DeepMind, largest Ollama-hosted variant

Model: ollama-cloud/qwen3.5:397b
Context: 256K | Output: 64K
Input: text+image
Capabilities: vision, tools, thinking
Note: Alibaba, 397B cloud-only variant

Model: ollama-cloud/nemotron-3-super
Context: 256K | Output: 64K
Input: text
Capabilities: tools, thinking
Note: NVIDIA middle tier for collaborative agents and high-volume reasoning

Model: ollama-cloud/nemotron-3-nano:30b
Context: 1M | Output: 128K
Input: text
Capabilities: tools, thinking
Note: NVIDIA, tied-largest Ollama context (1M), small efficient MoE

Model: ollama-cloud/mistral-large-3:675b
Context: 256K | Output: 256K
Input: text+image
Capabilities: vision, tools (no reasoning)
Note: Mistral 675B, no reasoning capability

Model: ollama-cloud/deepseek-v4-flash:0731
Context: 1M | Output: 1M
Input: text
Capabilities: tools, thinking
Note: dated snapshot of the official V4 Flash release, unique to Ollama Cloud

Model: ollama-cloud/deepseek-v4-pro:0813
Context: 1M | Output: 1M
Input: text
Capabilities: tools, thinking
Note: dated snapshot of the official V4 Pro release, unique to Ollama Cloud

### Overlapping models (also on Go, separate limits)

Model: ollama-cloud/deepseek-v4-flash
Context: 1M | Output: 1M (Ollama) vs 384K (Go)
Input: text
Note: free on Ollama Cloud, larger output limit than Go

Model: ollama-cloud/deepseek-v4-pro
Context: 1M | Output: 1M (Ollama) vs 384K (Go)
Input: text
Note: free on Ollama Cloud, larger output limit than Go

Model: ollama-cloud/deepseek-v4.1-flash
Context: 1M | Output: 384K
Input: text+image
Note: free on Ollama Cloud, specs match Go

Model: ollama-cloud/glm-5.1
Context: 202K | Output: 128K (Ollama) vs 32K (Go)
Input: text
Note: free on Ollama Cloud, larger output limit than Go

Model: ollama-cloud/glm-5.2
Context: 976K | Output: 128K
Input: text
Note: free on Ollama Cloud, specs close to Go

Model: ollama-cloud/glm-5.3
Context: 1M | Output: 128K
Input: text
Note: free on Ollama Cloud, specs match Go

Model: ollama-cloud/glm-5.3-flash
Context: 1M | Output: 128K
Input: text+image+video+pdf
Note: free on Ollama Cloud, specs match Go

Model: ollama-cloud/kimi-k2.5
Context: 256K | Output: 256K
Input: text+image
Note: removed from Go, available on Ollama Cloud only
Skip: K2.6 or K2.7 Code better for most tasks

Model: ollama-cloud/kimi-k2.6
Context: 256K | Output: 256K (Ollama) vs 64K (Go)
Input: text+image
Note: free on Ollama Cloud, larger output limit than Go

Model: ollama-cloud/kimi-k2.7-code
Context: 256K | Output: 256K
Input: text+image
Note: free on Ollama Cloud, specs match Go

Model: ollama-cloud/kimi-k3
Context: 1M | Output: 128K
Input: text+image
Note: free on Ollama Cloud, frontier Kimi reasoning, also on Go (paid)

Model: ollama-cloud/minimax-m2.5
Context: 204K | Output: 128K
Input: text
Note: removed from Go, available on Ollama Cloud only
Skip: M2.7 or M3 better

Model: ollama-cloud/minimax-m2.7
Context: 196K (Ollama) vs 204K (Go) | Output: 196K (Ollama) vs 128K (Go)
Input: text
Note: free on Ollama Cloud, smaller context but larger output than Go

Model: ollama-cloud/minimax-m3
Context: 512K | Output: 128K
Input: text+image+video
Note: free on Ollama Cloud, no peak/off-peak pricing and no 1M tier unlike Go

Model: ollama-cloud/nemotron-3-ultra
Context: 256K | Output: 128K
Input: text
Capabilities: tools, thinking
Note: also on the Zen free tier (nemotron-3-ultra-free), Ollama is a separate provider

## Decision guide

Free and unlimited: opencode/space-bunny-free (best free pick — 1M context, 512K output, zero retention), opencode/muse-spark-1.3-contributor-free (best free coding model, 1M context, multimodal, trains on your data)
Highest volume / cheapest paid: opencode-go/muse-spark-1.3-contributor (226.6K), opencode-go/mimo-v2.6-flash (150.4K), opencode-go/deepseek-v4.1-flash (130K)
Best value reasoning: opencode-go/gpt-6-luna ($0.01/session, 1.05M context, vision+PDF), opencode-go/deepseek-v4.1-flash (130K req/mo), opencode-go/deepseek-v4-pro
Best value mid-tier: opencode-go/qwen3.8-flash, opencode-go/glm-5.3-flash, opencode-go/qwen3.7-plus
Need vision: opencode-go/mimo-v2.6-flash, opencode-go/deepseek-v4.1-flash, opencode-go/qwen3.8-flash, opencode-go/qwen3.7-plus, opencode-go/qwen3.6-plus, opencode-go/minimax-m3, opencode-go/gpt-6-luna, opencode-go/grok-4.7
Need video: opencode-go/mimo-v2.6-flash, opencode-go/qwen3.8-flash, opencode-go/qwen3.7-plus, opencode-go/qwen3.6-plus, opencode-go/minimax-m3, opencode-go/kimi-k2.7-code, opencode-go/kimi-k2.6, opencode-go/kimi-k3, opencode-go/qwen3.8-max
Need PDF input: opencode-go/muse-spark-1.3-contributor, opencode-go/glm-5.3-flash, opencode-go/gpt-6-luna, opencode-go/gpt-5.6-luna, opencode-go/grok-4.7
Need audio input: opencode-go/mimo-v2.6-flash, opencode-go/mimo-v2.6-pro, opencode-go/muse-spark-1.3-contributor
Need large output (262K+): opencode-go/grok-4.7 (500K), opencode-go/space-bunny-free (524K, free), opencode-go/kimi-k2.7-code (262K), opencode-go/deepseek-v4.1-flash (384K)
Need Chinese codebases: opencode-go/glm-5.2
Cheapest per session: opencode/space-bunny-free ($0), opencode-go/muse-spark-1.3-contributor ($0.01), opencode-go/mimo-v2.6-flash ($0.01), opencode-go/gpt-6-luna ($0.01)
Highest Req/mo (least likely to hit the cap): opencode-go/muse-spark-1.3-contributor (226.6K), opencode-go/mimo-v2.6-flash (150.4K), opencode-go/deepseek-v4.1-flash (130K)
Widest $60/mo limits: longcat-2.0, deepseek-v4.1-flash, deepseek-v4-flash, muse-spark-1.3/1.2-contributor, mimo-v2.6-flash, mimo-v2.5, qwen3.7-plus, qwen3.6-plus, hy3, kimi-k2.7-code, kimi-k2.6, glm-5.3-flash, glm-5.2, glm-5.1, minimax-m3, minimax-m2.7
Tightest $15/mo limits (expect to hit the cap): gpt-6-luna, gpt-5.6-luna, deepseek-v4-pro, deepseek-v4-flash-vision-exp, glm-5.3, grok-4.7, grok-4.6, qwen3.8-max, kimi-k3, mimo-v2.6-pro, mimo-v2.5-pro
Budget exhausted: free models
Need cheapest GPT class: opencode-go/gpt-6-luna
Need frontier reasoning: opencode-go/qwen3.8-max, opencode-go/kimi-k3, opencode-go/qwen3.7-max
Privacy-critical (nothing retained, nothing trained on): opencode/space-bunny-free, or any $60-tier Go model outside the Muse Spark family

## Agent-to-model mapping

Agent model preferences are maintained in `opencode-models.json` (machine-readable, consumed by `opencode-agent-models-probe` at install time). Edit that file to adjust per-agent rankings; re-run `install.sh` to redeploy. This section is kept for human reference only — `opencode-models.json` is the source of truth.

Agent models sorted by best fit. Max 10. Provider prefix required: `opencode-go/` (Go), `opencode/` (free tier). The probe picks the first entry that is both listed in `free_models` and returned by `opencode models` — so every agent list must contain at least one currently-available free model or that agent silently gets no pin.

Agent: auditor (security audit, privacy-critical, 25 steps) — free pick opencode/space-bunny-free (zero retention)
Agent: debugger (bug diagnosis, high context, 40 steps)
Agent: implementer-quick (scaffolding, boilerplate, small edits, 15 steps)
Agent: implementer (features, bugs, refactors, tests, 30 steps)
Agent: planner (architecture, design, trade-off analysis, read-only, 30 steps)
Agent: researcher (web research, docs lookup, synthesis, 40 steps)
Agent: reviewer-quick (quick review, small diffs, triage, 15 steps)
Agent: reviewer (code review, verify correctness, 30 steps)

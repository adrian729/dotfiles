# Machine-readable model reference for OpenCode Go and free models. Fields only — no prose, no descriptions, no human-aimed text. Edit data only.

## Rules for editing this file + opencode-models.json

- Every model name is fully provider-prefixed: `opencode-go/` (Go), `opencode/` (free tier), `ollama-cloud/` (Ollama Cloud). Never bare, never `-cloud` suffix shorthand.
- Specs always inlined per model; never cross-reference another section ("same as Go entry"). LLM readers must not chase pointers — duplicate specs where models overlap providers (Ollama Cloud overlapping section).
- Agent-to-model mapping: the model lists live in `opencode-models.json`. This document's Agent section only describes agent purpose + JSON format constraints (max 10, sorted by fit, prefix rule). When syncing after model availability changes, update both files.
- `opencode-models.json` free_models: only models that `opencode-models free` should return. relay: subset of free_models usable without tools. agents: ranked preference lists, first available free model auto-selected by probe.
- Req/mo: sourced verbatim from opencode.ai/docs/go's own published estimate table (verified 2026-08-30), not derived. Cache %: cached/(cached+input) computed from that same page's published per-request token-pattern figures. Go rank: models ranked by Req/mo, descending (#1 = highest). Avg $/session: ($60 monthly cap ÷ Req/mo) × 20 requests — 20 is a fixed session-length assumption (this machine's own `opencode stats` average), not a vendor-reported figure.

## Limits

$12/5h, $30/wk, $60/mo rolling dollar-based windows. Free models don't count. Fallback to Zen credits via "Use balance" in console.

## Go models

Model: opencode-go/deepseek-v4-flash
Cost in/out/cached: $0.22 / $0.66 / $0.007
Avg $/session: $0.03
Context: 1M | Output: 384K
Input: text
Cache: 99% | Go rank: #4
Req/mo: 37.8K
Use: daily coding, boilerplate, prototyping, iterative edits
Skip: deep reasoning, architecture design

Model: opencode-go/deepseek-v4-flash-vision-exp
Cost in/out/cached: $0.22 / $0.66 / $0.007
Avg $/session: $0.06
Context: 1M | Output: 384K
Input: text+image
Cache: 99% | Go rank: #8
Req/mo: 18.9K
Use: image-in-the-loop coding, screenshot/diagram review, same price as plain Flash
Skip: non-visual tasks (plain Flash is identical price), production reliability (experimental)

Model: opencode-go/deepseek-v4-pro
Cost in/out/cached: $0.66 / $1.98 / $0.022
Avg $/session: $0.23
Context: 1M | Output: 384K
Input: text
Cache: 99% | Go rank: #18
Req/mo: 5.2K
Use: complex refactors, multi-step reasoning, code review
Skip: trivial tasks, quick edits

Model: opencode-go/mimo-v2.5
Cost in/out/cached: $0.14 / $0.28 / $0.0028
Avg $/session: $0.01
Context: 1M | Output: 128K
Input: text+image+audio+video
Cache: 99% | Go rank: #2
Req/mo: 150.4K
Use: vision tasks, highest volume, cheapest sessions
Skip: deep reasoning (Flash is smarter for same price)

Model: opencode-go/mimo-v2.5-pro
Cost in/out/cached: $0.435 / $0.87 / $0.003625
Avg $/session: $0.07
Context: 1M | Output: 128K
Input: text
Cache: 99% | Go rank: #10
Req/mo: 16.3K
Use: reasoning with Xiaomi approach
Skip: unless you specifically prefer Xiaomi over DeepSeek

Model: opencode-go/minimax-m3
Cost in/out/cached: $0.30 / $1.20 / $0.06 (≤512K); $0.60 / $2.40 / $0.12 (>512K)
Avg $/session: $0.07
Context: 1M | Output: 131K
Input: text+image+video
Cache: 99% | Go rank: #12
Req/mo: 16K
Use: efficient mid-tier coding, balanced cost-performance
Skip: tasks needing 1M context (premium tier over 512K)

Model: opencode-go/minimax-m2.7
Cost in/out/cached: $0.30 / $1.20 / $0.06
Avg $/session: $0.07
Context: 205K | Output: 131K
Input: text
Cache: 99% | Go rank: #9
Req/mo: 17K
Use: cheapest MiniMax sessions
Skip: tasks needing >205K context, M3 is better

Model: opencode-go/muse-spark-1.2-contributor
Cost in/out/cached: $0.10 / $0.20 / $0.002
Avg $/session: $0.01
Context: 1M | Output: 131K
Input: text+image+video+pdf+audio
Cache: 99% | Go rank: #1
Req/mo: 226.6K
Use: highest-volume cheapest sessions, full multimodal coding workflows, complex debugging
Skip: needing wide ecosystem/track record (newest family on Go)

Model: opencode-go/glm-5.3
Cost in/out/cached: $1.40 / $4.40 / $0.26
Avg $/session: $1.11
Context: 1M | Output: 131K
Input: text
Cache: 99% | Go rank: #22
Req/mo: 1.08K
Use: latest GLM flagship, finest-grained effort control (low/high/max), long-horizon coding and complex project delivery
Skip: not open-weight (closed) — GLM-5.2 is the open-weight flagship at the same price

Model: opencode-go/glm-5.3-flash
Cost in/out/cached: $0.075 / $0.25 / $0.015
Avg $/session: $0.15
Context: 1M | Output: 131K
Input: text+image+video+pdf
Cache: 98% | Go rank: #14
Req/mo: 7.9K
Use: cheapest GLM tier, native multimodal (image/video/PDF), efficient coding and long-horizon agent tasks
Skip: budget-critical volume (higher rank tier models go further per dollar)

Model: opencode-go/glm-5.2
Cost in/out/cached: $1.40 / $4.40 / $0.26
Avg $/session: $0.28
Context: 1M | Output: 131K
Input: text
Cache: 99% | Go rank: #19
Req/mo: 4.3K
Use: Chinese codebases, bilingual CN/EN docs, Chinese dev conventions, open-weight flagship
Skip: English-only work (too expensive for what you get)

Model: opencode-go/glm-5.1
Cost in/out/cached: $1.40 / $4.40 / $0.26
Avg $/session: $0.28
Context: 198K | Output: 32K
Input: text
Cache: 99% | Go rank: #20
Req/mo: 4.3K
Use: same as 5.2 but less context needed, tighter output
Skip: 5.2 is better if you have the context

Model: opencode-go/kimi-k2.7-code
Cost in/out/cached: $0.95 / $4.00 / $0.19
Avg $/session: $0.18
Context: 262K | Output: 262K
Input: text+image+video
Cache: 98% | Go rank: #16
Req/mo: 6.75K
Use: large code generation, big output responses
Skip: short tasks (expensive per session)

Model: opencode-go/kimi-k2.6
Cost in/out/cached: $0.95 / $4.00 / $0.16
Avg $/session: $0.21
Context: 262K | Output: 65K
Input: text+image+video
Cache: 98% | Go rank: #17
Req/mo: 5.75K
Use: general tasks needing vision+video
Skip: large output (use K2.7 Code), coding-specific (K2.7 Code better)

Model: opencode-go/kimi-k3
Cost in/out/cached: $3.00 / $15.00 / $0.30
Avg $/session: $2.45
Context: 1M | Output: 131K
Input: text+image+video
Cache: 99% | Go rank: #25
Req/mo: 490
Use: frontier Kimi reasoning, largest context of K2 family
Skip: budget sessions (very expensive output, lowest Req/mo on Go)

Model: opencode-go/qwen3.8-max
Cost in/out/cached: $2.00 / $6.00 / $0.25
Avg $/session: $1.48
Context: 1M | Output: 131K
Input: text+image+video
Cache: 99% | Go rank: #24
Req/mo: 810
Use: newest Qwen flagship, hardest problems, architecture design, complex debugging
Skip: everyday tasks (lowest Req/mo of any model on Go)

Model: opencode-go/qwen3.8-flash
Cost in/out/cached: $0.15 / $0.47 / $0.016
Avg $/session: $0.04
Context: 1M | Output: 131K
Input: text+image+video
Cache: 99% | Go rank: #5
Req/mo: 27K
Use: best value new mid-tier, vision, video, replaces 3.7 Plus at a lower price
Skip: tasks specifically needing 3.7 Plus/Max's higher output ceiling

Model: opencode-go/qwen3.7-max
Cost in/out/cached: $2.50 / $7.50 / $0.50
Avg $/session: $0.71
Context: 1M | Output: 65K
Input: text
Cache: 99% | Go rank: #21
Req/mo: 1.69K
Use: hardest problems, architecture design, complex debugging
Skip: everyday tasks (burns monthly limit in days)

Model: opencode-go/qwen3.7-plus
Cost in/out/cached: $0.40 / $1.60 / $0.04 (≤256K); $1.20 / $4.80 / $0.12 (>256K)
Avg $/session: $0.06
Context: 1M | Output: 65K
Input: text+image+video
Cache: 99% | Go rank: #6
Req/mo: 21.6K
Use: best value mid-tier reasoning, vision, video
Skip: tasks fully within 256K context (avoids premium tier)

Model: opencode-go/qwen3.6-plus
Cost in/out/cached: $0.50 / $3.00 / $0.05 (≤256K); $2.00 / $6.00 / $0.20 (>256K)
Avg $/session: $0.07
Context: 1M | Output: 65K
Input: text+image+video
Cache: 99% | Go rank: #11
Req/mo: 16.3K
Use: vision+video tasks
Skip: text-only work (3.7 Plus same price, newer)

Model: opencode-go/gpt-5.6-luna
Cost in/out/cached: $0.20 / $1.20 / $0.02 (≤272K); $0.40 / $1.80 / $0.04 (>272K)
Avg $/session: $0.12
Context: 1M | Output: 128K
Input: text
Cache: 98% | Go rank: #13
Req/mo: 10.25K
Use: cheapest GPT-5 class model, strong reasoning per dollar
Skip: tasks >272K context (premium tier), vision/video/audio

Model: opencode-go/grok-4.6
Cost in/out/cached: $2.00 / $6.00 / $0.50 (≤200K); $4.00 / $12.00 / $1.00 (>200K)
Avg $/session: $1.42
Context: 500K | Output: 500K
Input: text+image
Cache: 99% | Go rank: #23
Req/mo: 845
Use: massive output (500K), vision, large reasoning windows
Skip: budget work (expensive, premium tier over 200K)

Model: opencode-go/hy4-preview
Cost in/out/cached: $0.834 / $2.501 / $0.042
Avg $/session: $0.18
Context: 1M | Output: 64K
Input: text
Cache: 99% | Go rank: #15
Req/mo: 6.77K
Use: newer Tencent Hy preview, stronger agent workflows and complex task execution
Skip: preview status — Hy3 is the cheaper, more established choice for routine work

Model: opencode-go/hy3
Cost in/out/cached: $0.14 / $0.58 / $0.035
Avg $/session: $0.06
Context: 256K | Output: 64K
Input: text
Cache: 99% | Go rank: #7
Req/mo: 21.5K
Use: Tencent open-weight model, cheap input, good cache ratio
Skip: tasks needing >256K context, vision/video/audio

Model: opencode-go/longcat-2.0
Cost in/out/cached: $0.30 / $1.20 / $0.006
Avg $/session: $0.02
Context: 1M | Output: 131K
Input: text
Cache: 99% | Go rank: #3
Req/mo: 57.2K
Use: Meituan reasoning model, 1M context, tool calling, very cheap, very high volume
Skip: needing wide ecosystem/track record (newest family on Go)

## Free models

All free models cost $0. Data-use policy annotated per model, sourced from opencode.ai/docs/zen (verified 2026-08-30).

Model: opencode/big-pickle
Input: text
Privacy: data may be used to improve the model (free period)
Note: stealth model, unknown origin, experimental

Model: opencode/mimo-v2.5-free
Input: text+image+audio+video
Privacy: data may be used to improve the model (free period)
Note: same model as paid MiMo-V2.5, rate-limited

Model: opencode/ling-3.0-flash-fin-free
Input: text
Privacy: data may be used to improve the model (free period)
Note: finance-enhanced variant, replaces the deprecated plain ling-3.0-flash-free

Model: opencode/muse-spark-1.2-contributor-free
Input: text+image+video+pdf+audio
Privacy: prompts/completions used to train future Meta models, in exchange for the discount
Note: Meta-hosted, coding-focused, same model as paid Muse Spark 1.2 Contributor

Model: opencode/nemotron-3-ultra-free
Input: text
Privacy: NVIDIA trial — logged for security/product improvement, not linked to identity
Note: NVIDIA-hosted, limited trial

Model: opencode/nemotron-3.5-lightning-free
Input: text
Privacy: NVIDIA trial — logged for security/product improvement, not linked to identity
Note: NVIDIA-hosted, fast Nemotron MoE, limited trial

## Ollama Cloud (Free)

Separate provider — connect via /connect (ollama.com account + API key).
Free tier: light GPU-time usage, 1 concurrent model.
Usage levels: Low/Medium/High/Extra High determine GPU-time cost per request.
Overlapping models (same model as Go entries) have separate limits per provider.

### Models unique to Ollama Cloud

Model: ollama-cloud/gpt-oss:20b
Context: 128K | Output: 32K
Input: text
Capabilities: tools, thinking, variants (low/medium/high)
Note: OpenAI open-weight, Apache 2.0

Model: ollama-cloud/gpt-oss:120b
Context: 128K | Output: 32K
Input: text
Capabilities: tools, thinking, variants (low/medium/high)
Note: larger variant

Model: ollama-cloud/gemma4:31b
Context: 262K | Output: 262K
Input: text+image
Capabilities: vision, tools, thinking
Note: Google DeepMind, largest Ollama-hosted variant. Audio only on E2B/E4B sizes (not on Ollama)

Model: ollama-cloud/qwen3.5:397b
Context: 262K | Output: 65K
Input: text+image
Capabilities: vision, tools, thinking
Note: Alibaba, 397B cloud-only variant

Model: ollama-cloud/nemotron-3-super
Context: 262K | Output: 65K
Input: text
Capabilities: tools, thinking
Note: NVIDIA middle tier for collaborative agents and high-volume reasoning workloads

Model: ollama-cloud/nemotron-3-nano:30b
Context: 1M | Output: 131K
Input: text
Capabilities: tools, thinking
Note: NVIDIA, largest Ollama context (1M), small efficient MoE

Model: ollama-cloud/mistral-large-3:675b
Context: 262K | Output: 262K
Input: text+image
Capabilities: vision, tools (no reasoning)
Note: Mistral 675B, no reasoning capability

Model: ollama-cloud/deepseek-v4-flash:0731
Context: 1M | Output: 1M
Input: text
Capabilities: tools, thinking, variants (high/max)
Note: dated snapshot of the official V4 Flash release, unique to Ollama Cloud

### Overlapping models (also on Go, separate limits)

Model: ollama-cloud/deepseek-v4-flash
Context: 1M | Output: 1M (Ollama) vs 384K (Go)
Input: text
Note: free on Ollama Cloud, larger output limit than Go

Model: ollama-cloud/deepseek-v4-pro
Context: 1M | Output: 1M (Ollama) vs 384K (Go)
Input: text
Note: free on Ollama Cloud, larger output limit than Go

Model: ollama-cloud/glm-5.1
Context: 198K | Output: 131K (Ollama) vs 32K (Go)
Input: text
Note: free on Ollama Cloud, larger output limit than Go

Model: ollama-cloud/glm-5.2
Context: 953K | Output: 131K
Input: text
Note: free on Ollama Cloud, specs close to Go

Model: ollama-cloud/glm-5.3
Context: 1M | Output: 131K
Input: text
Note: free on Ollama Cloud, specs match Go

Model: ollama-cloud/glm-5.3-flash
Context: 1M | Output: 131K
Input: text+image+video+pdf
Note: free on Ollama Cloud, specs match Go

Model: ollama-cloud/kimi-k2.5
Context: 262K | Output: 262K
Input: text+image
Note: removed from Go, available on Ollama Cloud only
Skip: K2.6 or K2.7 Code better for most tasks

Model: ollama-cloud/kimi-k2.6
Context: 262K | Output: 262K (Ollama) vs 65K (Go)
Input: text+image
Note: free on Ollama Cloud, larger output limit than Go

Model: ollama-cloud/kimi-k2.7-code
Context: 262K | Output: 262K
Input: text+image
Note: free on Ollama Cloud, specs match Go

Model: ollama-cloud/kimi-k3
Context: 1M | Output: 131K (Ollama) vs 131K (Go)
Input: text+image
Note: free on Ollama Cloud, frontier Kimi reasoning, also on Go (paid)

Model: ollama-cloud/minimax-m2.5
Context: 205K | Output: 131K
Input: text
Note: removed from Go, available on Ollama Cloud only
Skip: M2.7 or M3 better

Model: ollama-cloud/minimax-m2.7
Context: 192K | Output: 197K (Ollama) vs 205K/131K (Go)
Input: text
Note: free on Ollama Cloud, smaller context but larger output than Go

Model: ollama-cloud/minimax-m3
Context: 512K | Output: 131K
Input: text+image+video
Note: free on Ollama Cloud, no premium tier unlike Go (Go is 1M tiered)

Model: ollama-cloud/nemotron-3-ultra
Context: 262K | Output: 128K
Input: text
Capabilities: tools, thinking
Note: also on Go free tier (nemotron-3-ultra-free), Ollama is separate

## Decision guide

Highest volume / cheapest: opencode-go/muse-spark-1.2-contributor, opencode-go/mimo-v2.5
Best open reasoning: opencode-go/qwen3.7-max, opencode-go/deepseek-v4-pro
Best value mid-tier: opencode-go/qwen3.8-flash, opencode-go/qwen3.7-plus, opencode-go/gpt-5.6-luna
Need vision: opencode-go/mimo-v2.5, opencode-go/qwen3.8-flash, opencode-go/qwen3.7-plus, opencode-go/qwen3.6-plus, opencode-go/minimax-m3, opencode-go/grok-4.6
Need video: opencode-go/mimo-v2.5, opencode-go/kimi-k2.7-code, opencode-go/kimi-k2.6, opencode-go/qwen3.8-flash, opencode-go/qwen3.7-plus, opencode-go/qwen3.6-plus, opencode-go/minimax-m3, opencode-go/kimi-k3
Need PDF input: opencode-go/muse-spark-1.2-contributor, opencode-go/glm-5.3-flash
Need audio input: opencode-go/mimo-v2.5, opencode-go/muse-spark-1.2-contributor
Need large output (262K+): opencode-go/kimi-k2.7-code (262K), opencode-go/grok-4.6 (500K)
Need Chinese codebases: opencode-go/glm-5.2
Cheapest per session: opencode-go/muse-spark-1.2-contributor ($0.01), opencode-go/mimo-v2.5 ($0.01), opencode-go/longcat-2.0 ($0.02)
Highest Req/mo (least likely to hit the cap): opencode-go/muse-spark-1.2-contributor (226.6K), opencode-go/mimo-v2.5 (150.4K), opencode-go/longcat-2.0 (57.2K)
Budget exhausted: free models
Need cheapest GPT class: opencode-go/gpt-5.6-luna
Need NVIDIA 120B reasoning: ollama-cloud/nemotron-3-super
Need 1M context NVIDIA: ollama-cloud/nemotron-3-nano:30b
Need Mistral 675B: ollama-cloud/mistral-large-3:675b (no reasoning)
Need frontier Kimi: opencode-go/kimi-k3 (lowest Req/mo of any Go model, very expensive output)

## Agent-to-model mapping

Agent model preferences are maintained in `opencode-models.json` (machine-readable, consumed by `opencode-agent-models-probe` at install time). Edit that file to adjust per-agent rankings; re-run `install.sh` to redeploy. This section is kept for human reference only — `opencode-models.json` is the source of truth.

Agent models sorted by best fit. Max 10. Provider prefix required: `opencode-go/` (Go), `opencode/` (free tier), `ollama-cloud/` (Ollama Cloud).

Agent: auditor (security audit, privacy-critical, 25 steps)
Agent: debugger (bug diagnosis, high context, 40 steps)
Agent: implementer-quick (scaffolding, boilerplate, small edits, 15 steps)
Agent: implementer (features, bugs, refactors, tests, 30 steps)
Agent: planner (architecture, design, trade-off analysis, read-only, 30 steps)
Agent: researcher (web research, docs lookup, synthesis, 40 steps)
Agent: reviewer-quick (quick review, small diffs, triage, 15 steps)
Agent: reviewer (code review, verify correctness, 30 steps)

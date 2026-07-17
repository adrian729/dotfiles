# Machine-readable model reference for OpenCode Go and free models. Fields only — no prose, no descriptions, no human-aimed text. Edit data only.

## Rules for editing this file + opencode-models.json

- Every model name is fully provider-prefixed: `opencode-go/` (Go), `opencode/` (free tier), `ollama-cloud/` (Ollama Cloud). Never bare, never `-cloud` suffix shorthand.
- Specs always inlined per model; never cross-reference another section ("same as Go entry"). LLM readers must not chase pointers — duplicate specs where models overlap providers (Ollama Cloud overlapping section).
- Agent-to-model mapping: the model lists live in `opencode-models.json`. This document's Agent section only describes agent purpose + JSON format constraints (max 10, sorted by fit, prefix rule). When syncing after model availability changes, update both files.
- `opencode-models.json` free_models: only models that `opencode-models free` should return. relay: subset of free_models usable without tools. agents: ranked preference lists, first available free model auto-selected by probe.

## Limits

$12/5h, $30/wk, $60/mo rolling dollar-based windows. Free models don't count. Fallback to Zen credits via "Use balance" in console.

## Go models

Model: opencode-go/deepseek-v4-flash
Cost in/out/cached: $0.14 / $0.28 / $0.0028
Avg $/session: $0.08
Context: 1M | Output: 384K
Input: text
Cache: 96% | Go rank: #1
Req/mo: 158K
Use: daily coding, boilerplate, prototyping, iterative edits
Skip: deep reasoning, architecture design

Model: opencode-go/deepseek-v4-pro
Cost in/out/cached: $0.44 / $0.87 / $0.0036
Avg $/session: $0.58
Context: 1M | Output: 384K
Input: text
Cache: 97% | Go rank: #2
Req/mo: 17K
Use: complex refactors, multi-step reasoning, code review
Skip: trivial tasks, quick edits

Model: opencode-go/mimo-v2.5
Cost in/out/cached: $0.14 / $0.28 / $0.0028
Avg $/session: $0.06
Context: 1M | Output: 128K
Input: text+image+audio+video
Cache: 95% | Go rank: #4
Req/mo: 150K
Use: vision tasks, highest volume, cheapest sessions
Skip: deep reasoning (Flash is smarter for same price)

Model: opencode-go/mimo-v2.5-pro
Cost in/out/cached: $0.44 / $0.87 / $0.0036
Avg $/session: $0.56
Context: 1M | Output: 128K
Input: text
Cache: 96% | Go rank: #7
Req/mo: 16K
Use: reasoning with Xiaomi approach
Skip: unless you specifically prefer Xiaomi over DeepSeek

Model: opencode-go/minimax-m3
Cost in/out/cached: $0.30 / $1.20 / $0.06 (≤512K); $0.60 / $2.40 / $0.12 (>512K)
Avg $/session: $0.45
Context: 1M | Output: 131K
Input: text+image+video
Cache: 95% | Go rank: #5
Req/mo: 16K
Use: efficient mid-tier coding, balanced cost-performance
Skip: tasks needing 1M context (premium tier over 512K)

Model: opencode-go/minimax-m2.7
Cost in/out/cached: $0.30 / $1.20 / $0.06
Avg $/session: $0.17
Context: 205K | Output: 131K
Input: text
Cache: 91% | Go rank: #12
Req/mo: 17K
Use: cheapest MiniMax sessions
Skip: tasks needing >205K context, M3 is better

Model: opencode-go/glm-5.2
Cost in/out/cached: $1.40 / $4.40 / $0.26
Avg $/session: $2.26
Context: 1M | Output: 131K
Input: text
Cache: 85% | Go rank: #3
Req/mo: 4.3K
Use: Chinese codebases, bilingual CN/EN docs, Chinese dev conventions
Skip: English-only work (too expensive for what you get)

Model: opencode-go/glm-5.1
Cost in/out/cached: $1.40 / $4.40 / $0.26
Avg $/session: $1.21
Context: 198K | Output: 32K
Input: text
Cache: 87% | Go rank: #10
Req/mo: 4.3K
Use: same as 5.2 but less context needed, tighter output
Skip: 5.2 is better if you have the context

Model: opencode-go/kimi-k2.7-code
Cost in/out/cached: $0.95 / $4.00 / $0.19
Avg $/session: $1.04
Context: 262K | Output: 262K
Input: text+image+video
Cache: 96% | Go rank: #6
Req/mo: 9.3K
Use: large code generation, big output responses
Skip: short tasks (expensive per session)

Model: opencode-go/kimi-k2.6
Cost in/out/cached: $0.95 / $4.00 / $0.16
Avg $/session: $0.83
Context: 262K | Output: 65K
Input: text+image+video
Cache: 92% | Go rank: #9
Req/mo: 5.8K
Use: general tasks needing vision+video
Skip: large output (use K2.7 Code), coding-specific (K2.7 Code better)

Model: opencode-go/kimi-k3
Cost in/out/cached: $3.00 / $15.00 / $0.30
Avg $/session: --
Context: 1M | Output: 131K
Input: text+image+video
Cache: -- | Go rank: --
Req/mo: --
Use: frontier Kimi reasoning, largest context of K2 family
Skip: budget sessions (2x usage multiplier, very expensive output)

Model: opencode-go/qwen3.7-max
Cost in/out/cached: $2.50 / $7.50 / $0.50
Avg $/session: $1.53
Context: 1M | Output: 65K
Input: text
Cache: 97% | Go rank: #11
Req/mo: 4.8K
Use: hardest problems, architecture design, complex debugging
Skip: everyday tasks (burns monthly limit in days)

Model: opencode-go/qwen3.7-plus
Cost in/out/cached: $0.40 / $1.60 / $0.04 (≤256K); $1.20 / $4.80 / $0.12 (>256K)
Avg $/session: $0.58
Context: 1M | Output: 65K
Input: text+image+video
Cache: 94% | Go rank: #8
Req/mo: 22K
Use: best value mid-tier reasoning, vision, video
Skip: tasks fully within 256K context (avoids premium tier)

Model: opencode-go/qwen3.6-plus
Cost in/out/cached: $0.50 / $3.00 / $0.05 (≤256K); $2.00 / $6.00 / $0.20 (>256K)
Avg $/session: $0.57
Context: 1M | Output: 65K
Input: text+image+video
Cache: 88% | Go rank: #13
Req/mo: 16K
Use: vision+video tasks
Skip: text-only work (3.7 Plus same price, newer)

Model: opencode-go/grok-4.5
Cost in/out/cached: $2.00 / $6.00 / $0.50 (≤200K); $4.00 / $12.00 / $1.00 (>200K)
Avg $/session: --
Context: 500K | Output: 500K
Input: text+image
Cache: -- | Go rank: --
Req/mo: --
Use: massive output (500K), vision, large reasoning windows
Skip: budget work (expensive, premium tier over 200K)

## Free models

All free models cost $0. Data-use policy annotated per model.

Model: opencode/deepseek-v4-flash-free
Input: text
Privacy: data may train model
Note: same model as paid Flash, rate-limited

Model: opencode/mimo-v2.5-free
Input: text+image+audio+video
Privacy: data may train model
Note: same model as paid MiMo-V2.5, rate-limited

Model: opencode/big-pickle
Input: unknown
Privacy: data used for model improvement
Note: stealth model, unknown origin, experimental

Model: opencode/north-mini-code-free
Input: text
Privacy: data retained per Cohere ToS
Note: Cohere-hosted, code-focused

Model: opencode/nemotron-3-ultra-free
Input: text
Privacy: logged for NVIDIA improvement, trial use
Note: NVIDIA-hosted, limited trial

Model: opencode/hy3-free
Input: text
Privacy: unknown
Note: Tencent-hosted, experimental

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
Capabilities: vision, tools, thinking, variants (low/medium/high)
Note: Google DeepMind, largest Ollama-hosted variant. Audio only on E2B/E4B sizes (not on Ollama)

Model: ollama-cloud/qwen3.5:397b
Context: 262K | Output: 65K
Input: text+image
Capabilities: vision, tools, thinking
Note: Alibaba, 397B cloud-only variant

Model: ollama-cloud/nemotron-3-super
Context: 262K | Output: 65K
Input: text
Capabilities: tools, thinking, variants (low/medium/high)
Note: NVIDIA 120B MoE (12B active), 7 languages

Model: ollama-cloud/nemotron-3-nano:30b
Context: 1M | Output: 131K
Input: text
Capabilities: tools, thinking, variants (low/medium/high)
Note: NVIDIA, largest Ollama context (1M), 30B

Model: ollama-cloud/mistral-large-3:675b
Context: 262K | Output: 262K
Input: text+image
Capabilities: vision, tools (no reasoning)
Note: Mistral 675B, no reasoning capability

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
Capabilities: tools, thinking, variants (low/medium/high)
Note: also on Go free tier (nemotron-3-ultra-free), Ollama is separate
Skip: nemotron-3-super better unless you need ultra

## Decision guide

Highest volume / cheapest: opencode-go/deepseek-v4-flash, opencode-go/mimo-v2.5
Best open reasoning: opencode-go/qwen3.7-max, opencode-go/deepseek-v4-pro
Best value mid-tier: opencode-go/qwen3.7-plus, opencode-go/minimax-m3
Need vision: opencode-go/mimo-v2.5, opencode-go/qwen3.7-plus, opencode-go/qwen3.6-plus, opencode-go/minimax-m3, opencode-go/grok-4.5
Need video: opencode-go/mimo-v2.5, opencode-go/kimi-k2.7-code, opencode-go/kimi-k2.6, opencode-go/qwen3.7-plus, opencode-go/qwen3.6-plus, opencode-go/minimax-m3, opencode-go/kimi-k3
Need PDF input: opencode-go/mimo-v2.5 (was mimo-v2-omni — removed from Go)
Need audio input: opencode-go/mimo-v2.5
Need large output (262K+): opencode-go/kimi-k2.7-code (262K), opencode-go/grok-4.5 (500K)
Need Chinese codebases: opencode-go/glm-5.2
Cheapest per session: opencode-go/mimo-v2.5 ($0.06), opencode-go/deepseek-v4-flash ($0.08)
Best cache ratio (lower effective cost): opencode-go/deepseek-v4-pro (97%), opencode-go/qwen3.7-max (97%), opencode-go/deepseek-v4-flash (96%), opencode-go/mimo-v2.5-pro (96%), opencode-go/kimi-k2.7-code (96%)
Budget exhausted: free models
Need OpenAI open-weights: ollama-cloud/gpt-oss:20b, ollama-cloud/gpt-oss:120b
Need Google DeepMind + vision: ollama-cloud/gemma4:31b (audio only on E2B/E4B sizes)
Need NVIDIA 120B reasoning: ollama-cloud/nemotron-3-super
Need 1M context NVIDIA: ollama-cloud/nemotron-3-nano:30b
Need Mistral 675B: ollama-cloud/mistral-large-3:675b (no reasoning)
Need frontier Kimi: opencode-go/kimi-k3 (2x usage multiplier, very expensive output)

## Agent-to-model mapping

Agent model preferences are maintained in `opencode-models.json` (machine-readable, consumed by `opencode-agent-models-probe` at install time). Edit that file to adjust per-agent rankings; re-run `install.sh` to redeploy. This section is kept for human reference only — `opencode-models.json` is the source of truth.

Agent models sorted by best fit. Max 10. Provider prefix required: `opencode-go/` (Go), `opencode/` (free tier), `ollama-cloud/` (Ollama Cloud).

Agent: auditor (security audit, privacy-critical, no free models — data may train)
Agent: debugger (bug diagnosis, high context, 40 steps)
Agent: implementer-quick (scaffolding, boilerplate, small edits, 15 steps)
Agent: implementer (features, bugs, refactors, tests, 30 steps)
Agent: planner (architecture, design, trade-off analysis, read-only, 30 steps)
Agent: researcher (web research, docs lookup, synthesis, 40 steps)
Agent: reviewer-quick (quick review, small diffs, triage, 15 steps)
Agent: reviewer (code review, verify correctness, 30 steps)


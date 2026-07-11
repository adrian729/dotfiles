# Machine-readable model reference for OpenCode Go and free models. Fields only — no prose, no descriptions, no human-aimed text. Edit data only.

## Limits

$12/5h, $30/wk, $60/mo rolling dollar-based windows. Free models don't count. Fallback to Zen credits via "Use balance" in console.

## Go models

Model: deepseek-v4-flash
Cost in/out/cached: $0.14 / $0.28 / $0.0028
Avg $/session: $0.08
Context: 1M | Output: 384K
Input: text
Cache: 96% | Go rank: #1
Req/mo: 158K
Use: daily coding, boilerplate, prototyping, iterative edits
Skip: deep reasoning, architecture design

Model: deepseek-v4-pro
Cost in/out/cached: $1.74 / $3.48 / $0.0145
Avg $/session: $0.58
Context: 1M | Output: 384K
Input: text
Cache: 97% | Go rank: #2
Req/mo: 17K
Use: complex refactors, multi-step reasoning, code review
Skip: trivial tasks, quick edits

Model: mimo-v2.5
Cost in/out/cached: $0.14 / $0.28 / $0.0028
Avg $/session: $0.06
Context: 1M | Output: 131K
Input: text+image+audio+video
Cache: 95% | Go rank: #4
Req/mo: 150K
Use: vision tasks, highest volume, cheapest sessions
Skip: deep reasoning (Flash is smarter for same price)

Model: mimo-v2.5-pro
Cost in/out/cached: $1.74 / $3.48 / $0.0145
Avg $/session: $0.56
Context: 1M | Output: 131K
Input: text
Cache: 96% | Go rank: #7
Req/mo: 16K
Use: reasoning with Xiaomi approach
Skip: unless you specifically prefer Xiaomi over DeepSeek

Model: mimo-v2-pro
Cost in/out: $1.00 / $3.00
Avg $/session: $9.34
Context: 1M | Output: 131K
Input: text
Cache: 88% | Go rank: --
Req/mo: very low
Use: extremely long sessions (avg 24M tokens)
Skip: nearly abandoned, usage crashed 97%

Model: mimo-v2-omni
Cost in/out: $0.40 / $2.00
Avg $/session: $2.14
Context: 262K | Output: 131K
Input: text+image+audio+video+pdf
Cache: 84% | Go rank: --
Req/mo: very low
Use: PDF, audio, or video input
Skip: everything else (V2.5 cheaper and faster)

Model: minimax-m3
Cost in/out/cached: $0.30 / $1.20 / $0.06
Avg $/session: $0.45
Context: 512K | Output: 128K
Input: text+image+video
Cache: 95% | Go rank: #5
Req/mo: 16K
Use: efficient mid-tier coding, balanced cost-performance
Skip: tasks needing 1M context

Model: minimax-m2.7
Cost in/out/cached: $0.30 / $1.20 / $0.06
Avg $/session: $0.17
Context: 205K | Output: 131K
Input: text
Cache: 91% | Go rank: #12
Req/mo: 17K
Use: cheapest MiniMax sessions
Skip: tasks needing >205K context, M3 is better

Model: minimax-m2.5
Cost in/out/cached: $0.30 / $1.20 / $0.06
Avg $/session: $0.27
Context: 205K | Output: 131K
Input: text
Cache: 87% | Go rank: #16
Req/mo: very low
Use: fallback if M3 and M2.7 unavailable
Skip: M3 is better in every way

Model: glm-5.2
Cost in/out/cached: $1.40 / $4.40 / $0.26
Avg $/session: $2.26
Context: 1M | Output: 131K
Input: text
Cache: 85% | Go rank: #3
Req/mo: 4.3K
Use: Chinese codebases, bilingual CN/EN docs, Chinese dev conventions
Skip: English-only work (too expensive for what you get)

Model: glm-5.1
Cost in/out/cached: $1.40 / $4.40 / $0.26
Avg $/session: $1.21
Context: 200K | Output: 131K
Input: text
Cache: 87% | Go rank: #10
Req/mo: 4.3K
Use: same as 5.2 but less context needed
Skip: 5.2 is better if you have the context

Model: glm-5
Cost in/out: $1.00 / $3.20
Avg $/session: $0.91
Context: 205K | Output: 131K
Input: text
Cache: 86% | Go rank: #15
Req/mo: very low
Use: fallback if 5.2/5.1 unavailable
Skip: deprecating, usage dropping 57%

Model: kimi-k2.7-code
Cost in/out/cached: $0.95 / $4.00 / $0.19
Avg $/session: $1.04
Context: 262K | Output: 262K
Input: text+image+video
Cache: 96% | Go rank: #6
Req/mo: 9.3K
Use: large code generation, big output responses
Skip: short tasks (expensive per session)

Model: kimi-k2.6
Cost in/out/cached: $0.95 / $4.00 / $0.16
Avg $/session: $0.83
Context: 262K | Output: 262K
Input: text+image+video
Cache: 92% | Go rank: #9
Req/mo: 5.8K
Use: general tasks needing large output
Skip: coding-specific tasks (K2.7 Code better)

Model: kimi-k2.5
Cost in/out/cached: $0.60 / $3.00 / $0.10
Avg $/session: $0.63
Context: 262K | Output: 262K
Input: text+image+video
Cache: 93% | Go rank: #14
Req/mo: very low
Use: avoid
Skip: deprecating, usage crashing 66%, use K2.6 or K2.7 Code

Model: qwen3.7-max
Cost in/out/cached: $2.50 / $7.50 / $0.50
Avg $/session: $1.53
Context: 1M | Output: 66K
Input: text
Cache: 97% | Go rank: #11
Req/mo: 4.8K
Use: hardest problems, architecture design, complex debugging
Skip: everyday tasks (burns monthly limit in days)

Model: qwen3.7-plus
Cost in/out/cached: $0.40 / $1.60 / $0.04 (≤256K); $1.20 / $4.80 / $0.12 (>256K)
Avg $/session: $0.58
Context: 1M | Output: 64K
Input: text+image
Cache: 94% | Go rank: #8
Req/mo: 22K
Use: best value mid-tier reasoning, vision
Skip: tasks fully within 256K context (avoids premium tier)

Model: qwen3.6-plus
Cost in/out/cached: $0.50 / $3.00 / $0.05 (≤256K); $2.00 / $6.00 / $0.20 (>256K)
Avg $/session: $0.57
Context: 1M | Output: 66K
Input: text+image+video
Cache: 88% | Go rank: #13
Req/mo: 16K
Use: vision+video tasks
Skip: text-only work (3.7 Plus same price, newer)

Model: qwen3.5-plus
Cost in/out: $0.40 / $2.40
Avg $/session: $0.16
Context: 1M | Output: 66K
Input: text+image+video
Cache: 70% | Go rank: #17
Req/mo: very low
Use: budget Qwen, multimodal on cheap
Skip: 3.6/3.7 Plus better for slightly more

Model: hy3-preview
Cost in/out: $0.07 / $0.26
Avg $/session: $1.45
Context: 256K | Output: 64K
Input: text
Cache: 81% | Go rank: #18
Req/mo: very low
Use: experimental, cheapest per-token pricing
Skip: production work, minimal usage

## Free models

Model: deepseek-v4-flash-free
Cost: $0
Input: text
Privacy: data may train model
Note: same model as paid Flash, rate-limited

Model: mimo-v2.5-free
Cost: $0
Input: text+image+audio+video
Privacy: data may train model
Note: same model as paid MiMo-V2.5, rate-limited

Model: big-pickle
Cost: $0
Input: unknown
Privacy: data used for model improvement
Note: stealth model, unknown origin, experimental

Model: north-mini-code-free
Cost: $0
Input: text
Privacy: data retained per Cohere ToS
Note: Cohere-hosted, code-focused

Model: nemotron-3-ultra-free
Cost: $0
Input: text
Privacy: logged for NVIDIA improvement, trial use
Note: NVIDIA-hosted, limited trial

Model: hy3-free
Cost: $0
Input: text
Privacy: unknown
Note: Tencent-hosted, experimental

## Ollama Cloud (Free)

Separate provider — connect via /connect (ollama.com account + API key).
Free tier: light GPU-time usage, 1 concurrent model.
Usage levels: Low/Medium/High/Extra High determine GPU-time cost per request.
Overlapping models (same model as Go entries above) have separate limits per provider.

### Models unique to Ollama Cloud

Model: gpt-oss:20b-cloud
Usage level: Low
Context: 128K
Input: text
Capabilities: tools, thinking
Note: OpenAI open-weight, Apache 2.0

Model: gpt-oss:120b-cloud
Usage level: Medium
Context: 128K
Input: text
Capabilities: tools, thinking
Note: larger variant

Model: gemma4:cloud
Usage level: Medium
Context: 128K-256K (variant-dependent)
Input: text+image (all), audio (E2B/E4B only)
Capabilities: vision, tools, thinking, audio
Note: Google DeepMind, multiple sizes (E2B/E4B/12B/26B/31B)

Model: qwen3-coder:480b-cloud
Usage level: High
Context: 256K (1M extrapolated)
Input: text
Capabilities: tools, thinking
Note: Alibaba, coding-specialized, 480B MoE

Model: qwen3.5:cloud
Usage level: Medium
Context: 256K
Input: text+image
Capabilities: vision, tools, thinking
Note: Alibaba, 8 sizes (0.8B to 397B), 397B cloud-only

Model: nemotron-3-super:cloud
Usage level: Medium
Context: 256K
Input: text
Capabilities: tools, thinking
Note: NVIDIA 120B MoE (12B active), 7 languages

### Overlapping models (also on Go, separate limits)

Model: deepseek-v4-flash
Usage level: Medium
Specs: same as Go entry

Model: deepseek-v4-pro
Usage level: Extra High
Specs: same as Go entry

Model: glm-5.2
Usage level: High
Specs: same as Go entry

Model: glm-5.1
Usage level: High
Specs: same as Go entry

Model: kimi-k2.7-code
Usage level: High
Specs: same as Go entry

Model: kimi-k2.6
Usage level: High
Specs: same as Go entry

Model: minimax-m3
Usage level: High
Specs: same as Go entry

Model: minimax-m2.7
Usage level: Medium
Specs: same as Go entry

Model: minimax-m2.5
Usage level: Medium
Specs: same as Go entry

Model: nemotron-3-ultra
Usage level: High
Specs: same as Go entry (also on Go free tier)

## Decision guide

Highest volume / cheapest: deepseek-v4-flash, mimo-v2.5
Best open reasoning: qwen3.7-max, deepseek-v4-pro
Best value mid-tier: qwen3.7-plus, minimax-m3
Need vision: mimo-v2.5, qwen3.7-plus, qwen3.6-plus, minimax-m3
Need video: mimo-v2.5, kimi-k2.7-code, kimi-k2.6, qwen3.6-plus
Need PDF input: mimo-v2-omni
Need audio input: mimo-v2.5, mimo-v2-omni
Need large output (262K): kimi-k2.7-code, kimi-k2.6
Need Chinese codebases: glm-5.2
Cheapest per session: mimo-v2.5 ($0.06), deepseek-v4-flash ($0.08)
Best cache ratio (lower effective cost): deepseek-v4-pro (97%), deepseek-v4-flash (96%), mimo-v2.5-pro (96%), kimi-k2.7-code (96%), qwen3.7-max (97%)
Budget exhausted: free models
Need OpenAI open-weights: gpt-oss (Ollama Cloud)
Need Google DeepMind + audio: gemma4 (Ollama Cloud)
Need coding-specialized 480B: qwen3-coder (Ollama Cloud)
Need NVIDIA 120B reasoning: nemotron-3-super (Ollama Cloud)

## Agent-to-model mapping

Agent model preferences are now maintained in `opencode-models.json` (machine-readable, consumed by `opencode-agent-models-probe` at install time). Edit that file to adjust per-agent rankings; re-run `install.sh` to redeploy. This section is kept for human reference only — `opencode-models.json` is the source of truth.

Agent models sorted by best fit. Max 10. Provider annotated only if not Go.

Agent: auditor (security audit, privacy-critical)
Models: qwen3.7-max, deepseek-v4-pro, gpt-oss:120b-cloud (Ollama Cloud), qwen3.7-plus, nemotron-3-super:cloud (Ollama Cloud), deepseek-v4-flash, minimax-m3, kimi-k2.7-code, gpt-oss:20b-cloud (Ollama Cloud), qwen3-coder:480b-cloud (Ollama Cloud)
Note: no free models — data may train, unsafe for security

Agent: debugger (bug diagnosis, high context, 40 steps)
Models: deepseek-v4-flash, deepseek-v4-pro, qwen3.7-plus, qwen3.7-max, minimax-m3, deepseek-v4-flash-free (Free), kimi-k2.7-code, gpt-oss:120b-cloud (Ollama Cloud), qwen3-coder:480b-cloud (Ollama Cloud), gpt-oss:20b-cloud (Ollama Cloud)

Agent: implementer-quick (scaffolding, boilerplate, small edits, 15 steps)
Models: deepseek-v4-flash, deepseek-v4-flash-free (Free), mimo-v2.5, qwen3.7-plus, minimax-m3, gpt-oss:20b-cloud (Ollama Cloud), gpt-oss:120b-cloud (Ollama Cloud), nemotron-3-super:cloud (Ollama Cloud), deepseek-v4-pro, qwen3.5-plus

Agent: implementer (features, bugs, refactors, tests, 30 steps)
Models: deepseek-v4-flash, deepseek-v4-pro, qwen3.7-plus, qwen3.7-max, minimax-m3, kimi-k2.7-code, deepseek-v4-flash-free (Free), qwen3-coder:480b-cloud (Ollama Cloud), gpt-oss:120b-cloud (Ollama Cloud), nemotron-3-super:cloud (Ollama Cloud)

Agent: planner (architecture, design, trade-off analysis, read-only, 30 steps)
Models: qwen3.7-max, deepseek-v4-pro, qwen3.7-plus, gpt-oss:120b-cloud (Ollama Cloud), deepseek-v4-flash, minimax-m3, nemotron-3-super:cloud (Ollama Cloud), gpt-oss:20b-cloud (Ollama Cloud), kimi-k2.7-code, gemma4:cloud (Ollama Cloud)

Agent: researcher (web research, docs lookup, synthesis, 40 steps)
Models: deepseek-v4-flash, qwen3.7-plus, deepseek-v4-pro, minimax-m3, qwen3.7-max, deepseek-v4-flash-free (Free), gpt-oss:120b-cloud (Ollama Cloud), gpt-oss:20b-cloud (Ollama Cloud), nemotron-3-super:cloud (Ollama Cloud), gemma4:cloud (Ollama Cloud)

Agent: reviewer-quick (quick review, small diffs, triage, 15 steps)
Models: deepseek-v4-flash, deepseek-v4-flash-free (Free), mimo-v2.5, qwen3.7-plus, minimax-m3, gpt-oss:20b-cloud (Ollama Cloud), gpt-oss:120b-cloud (Ollama Cloud), nemotron-3-super:cloud (Ollama Cloud), deepseek-v4-pro, qwen3.5-plus

Agent: reviewer (code review, verify correctness, 30 steps)
Models: deepseek-v4-pro, qwen3.7-max, qwen3.7-plus, deepseek-v4-flash, minimax-m3, gpt-oss:120b-cloud (Ollama Cloud), nemotron-3-super:cloud (Ollama Cloud), kimi-k2.7-code, gpt-oss:20b-cloud (Ollama Cloud), gemma4:cloud (Ollama Cloud)

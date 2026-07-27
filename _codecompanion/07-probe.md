# Step 07 — Capability probe

**Goal** One re-runnable script that regenerates the tables in `findings.md`, so the evidence this plan rests on can be re-checked instead of trusted.

**Files** `claude/.local/scripts/acp-capability-probe`

**Depends on** nothing. **Pull this early** — see *Why this is urgent* below.

**Evidence** it *is* the evidence. Every table in `findings.md` marked *measured* comes from the throwaway scripts this step replaces.

## What it consolidates

Nine probes currently exist only as loose scripts in a session scratchpad, which will be deleted:

| Probe | Regenerates |
|---|---|
| handshake dump | *Provider capability matrix* |
| phase timing | *Process and session costs* |
| six-case contract spike | *Spike result* |
| session mode behaviour | *Provider capability matrix* → permission mode |
| session listing | *Session listing works and is cross-tool* |
| marginal process cost | *Concurrency* → RSS table |
| `dontAsk` write enforcement | *`dontAsk` refuses writes* |
| `fs` capability inertness, both directions | *The `fs` capability is inert* |
| which write path each agent takes | *The `fs` capability is inert* → agent table |
| per-mode read confinement | *The `fs` capability is inert* → mode table |
| three `OPENCODE_PERMISSION` configurations | *opencode over ACP: three permission configurations* |

## The load-bearing assertion

Most rows are informational. One is not: **"neither agent uses the client `fs/*` path."** The entire write-safety argument rests on session modes and permission sets governing the agents' own tools, which is only sufficient because that is the only path either agent uses. If a future agent version starts issuing `fs/write_text_file`, the mode stops being sufficient and the override in step 01 goes from insurance to essential — silently.

Make that assertion fail loudly, with a non-zero exit, not merely print a changed table.

## Why this is urgent

Everything here is version- and model-dependent, and both have already moved mid-investigation:

- `claude-agent-acp` went 0.55 → 0.59 and gained the entire `configOptions` mechanism the status panel depends on
- opencode's tool-use behaviour changed between two runs days apart — first pass ran `grep`/`read`/`glob`/`bash` and returned bare code, second pass used no tools and returned fenced code, at comparable latency

So `findings.md` is perishable by construction, and until this script exists the evidence for several claims lives only in a scratchpad. That is the argument for building it before the modules that depend on its conclusions, despite its position in the numbering.

## Done when

- one invocation regenerates every *measured* table in `findings.md`, in a form that can be pasted or diffed against the current text
- the client-`fs/*` assertion exits non-zero when violated, and this is verified by forcing it (stub an agent that sends `fs/write_text_file`)
- it degrades cleanly when an agent is missing from `PATH`, reporting which and continuing with the rest
- it runs without touching the repo: no writes outside a scratch directory, verified with `git status` before and after
- total runtime is stated in its own output, so a future reader knows what re-running costs

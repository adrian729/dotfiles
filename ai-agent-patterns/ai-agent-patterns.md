# AI Agent Usage Patterns

**Last reviewed:** 2026-07-09

A reference list of ways/patterns to use AI coding agents (Claude Code and peers), current as of July 2026. Each entry has an evidence label — **Proven** (production evidence exists), **Niche** (limited evidence, situational), **Unproven** (theoretical, no evidence), or **Superseded** (evidence exists, but better practices have replaced it). Each pattern also defines an **Automation** section describing how the agent should interact with the user when the pattern is invoked: what inputs it needs to collect, what steps it executes, and how it follows up. Patterns with non-obvious mechanics additionally carry a **How to implement** section; where the two overlap, How to implement is the source of truth for mechanics and Automation for the interaction flow.

**Escalation path**: complexity should be earned, not assumed. Start with a single interactive agent; move to loops when a task has testable completion criteria; move to multi-agent orchestration when a single context window bottlenecks; consider swarms only after fan-out and supervisor patterns have demonstrably bottlenecked. Each step up adds cost and failure modes — the sections below are ordered roughly along this path.

## Interactive single-agent workflows

- **[Proven] Pair programming (interactive mode)** — The default: converse with the agent, review as it works, steer mid-task. Best signal-to-noise for exploratory or ambiguous work where human judgment is needed continuously.
  - **Benefits**: Highest human oversight and steering ability; catches mistakes as they happen; ideal when the problem is poorly understood and direction changes frequently.
  - **Trade-offs**: High human attention cost — you must be actively engaged the whole time; doesn't scale to large tasks; human becomes the bottleneck on throughput.
  - **Automation**:
    - **Requirements**: task description, relevant files, steering preferences (small steps vs. full implementation).
    - **Agent flow**: 1. Ask user for the task. 2. Work in small, reviewable chunks, explaining each decision. 3. Wait for feedback after each chunk before proceeding. 4. Incorporate feedback immediately.
    - **Follow-up**: Ask "does this match what you wanted?" after each chunk. If direction changes, adjust and re-confirm understanding.
  - **Anti-patterns**: Rubber-stamping suggestions without reading diffs; staying in this mode for well-specified work that should be delegated; treating the agent as a faster typist instead of a collaborator.

- **[Proven] Plan-then-execute (plan mode)** — Agent researches and produces a plan for approval before touching code. Separates cheap thinking from expensive/risky doing; catches wrong approaches early.
  - **Benefits**: Catches wrong architectural choices before any code is written — the cheapest time to fix them; plan review takes ~1min of human time that pays for itself if it prevents one wrong direction; reduces wasted implementation effort on complex tasks.
  - **Trade-offs**: Extra latency (30s–2min) while the agent researches and plans; the plan can be confidently wrong in ways that only emerge during execution — review mitigates but doesn't eliminate this.
  - **Automation**:
    - **Requirements**: feature description, constraints, relevant files. Optionally: preferred approach.
    - **Agent flow**: 1. Ask user for the feature and constraints. 2. Research codebase and produce a written plan (files to change, approach, risks). 3. Present plan and ask for approval or changes. 4. Once approved, implement step by step. 5. If something unexpected comes up during implementation, stop and update the plan before continuing.
    - **Follow-up**: Present final diff and test results. Ask "does this match the plan? Any changes needed?"
  - **Anti-patterns**: Treating the plan as a binding contract rather than a checkpoint — good plans get updated during execution; rubber-stamping plans without scrutiny defeats the purpose; planning so exhaustively that execution is trivial and could have been done in the same time.

- **[Proven] Spec-driven development** — Write a spec/PRD first (or have the agent draft one), then implement against it. The spec becomes the source of truth the agent can be held to; scales better than chat history for larger features.
  - **Benefits**: Single source of truth for the agent across sessions; scales to large features that span multiple agent sessions or multiple engineers; spec review is cheaper than code review for catching requirement errors.
  - **Trade-offs**: Upfront spec effort (30min–2hr); spec can contain latent contradictions or infeasible requirements that only surface during implementation; less suited for exploratory UI or creative work where requirements emerge during building.
  - **Automation**:
    - **Requirements**: feature goal, acceptance criteria, constraints. Optionally: existing spec or ticket reference.
    - **Agent flow**: 1. Ask user for the feature goal and acceptance criteria. 2. Draft a spec covering requirements, architecture decisions, implementation plan, and test strategy. 3. Present spec for review; iterate until approved. 4. Once spec is approved, implement against it one section at a time. 5. If requirements change, update the spec and reset context before continuing.
    - **Follow-up**: Present the implemented feature with a checklist tracing back to spec sections. Ask "does the implementation match the spec?"
  - **Anti-patterns**: Spec so detailed the agent has no autonomy to make good micro-decisions; spec that contradicts itself (agent follows the letter while breaking intent); changing spec mid-implementation without resetting the agent's context.

- **[Proven] TDD with agents** — Write (or have the agent write) failing tests first, then let the agent iterate until green. Gives the agent an objective, machine-checkable target instead of "looks done."
  - **Benefits**: Objective pass/fail signal removes ambiguity about "done"; tests serve as documentation and regression protection; excellent for well-defined interfaces, bug fixes, and refactoring with coverage.
  - **Trade-offs**: Test-writing overhead (20–40% of total time); tests can encode the same misunderstandings as the implementation if not reviewed; the agent may overfit to make tests pass minimally.
  - **Automation**:
    - **Requirements**: interface or behavior to implement, edge cases, test framework and run command. Optionally: existing test file to extend.
    - **Agent flow**: 1. Ask user what behavior to implement and how to run tests. 2. Write failing tests that define the expected contract. 3. Present tests for user approval — tests must be reviewed before implementation starts. 4. Once tests are approved, implement until all tests pass. 5. If a test is wrong (not the implementation), ask user to clarify the expected behavior.
    - **Follow-up**: Run test suite and report results. Ask "are the tests correct? Does the behavior match what you expected?"
  - **Anti-patterns**: Writing tests that match buggy implementation (circular TDD); tests that pass trivially (e.g., no assertions); the agent overfitting to make tests pass without addressing the spirit of the requirement.

- **[Superseded] Vibe coding → agentic engineering** — Loose, conversation-driven iteration without reviewing output. Still fine for throwaway prototypes; for production work the practice has been superseded by "agentic engineering" — orchestrating agents with specs, verification, and review.
  - **Benefits**: Fastest path to a working prototype (minutes vs hours); no review overhead; useful for exploring feasibility or generating ideas quickly.
  - **Trade-offs**: No review means bugs, tech debt, and security issues are guaranteed to accumulate; the cost is deferred and paid later, often at higher interest. Dangerous for any code with a non-trivial blast radius.
  - **Automation**:
    - **Requirements**: prototype idea, threshold for "good enough." Note: confirm this is NOT for production.
    - **Agent flow**: 1. Ask user if this is for production. If yes, recommend a different pattern. 2. If prototype: ask what to explore. 3. Build quickly with minimal process. 4. Present result. 5. If the prototype is worth keeping, recommend switching to spec-driven or plan-then-execute to rebuild properly.
    - **Follow-up**: Ask "is this worth polishing for production?" If yes, transition to a proven pattern.
  - **Anti-patterns**: Using vibe coding for production systems or any code you'd deploy, test, or share; assuming "it ran" means "it's correct"; never circling back to refactor or review prototype output.

- **[Proven] Checkpoint / rewind** — Snapshot state (git commits, harness checkpoints) so you can roll back agent mistakes cheaply. Makes aggressive delegation safe: bad runs cost a revert, not a cleanup.
  - **Benefits**: Enables the most aggressive delegation patterns — you can let the agent try anything because reverting is free; safety net cost is negligible compared to the safety it enables; encourages experimentation.
  - **Trade-offs**: Git overhead from frequent commits; merge conflicts if multiple agents work in the same area in parallel; some changes can't be cleanly reverted (DB migrations, deployed infra, published packages).
  - **Automation**:
    - **Requirements**: none from the user — this is substrate, applied automatically underneath every other pattern. The agent needs only a clean commit to anchor to.
    - **Agent flow**: 1. Before starting any task, verify there's a recent commit to revert to; if not, create one. 2. Execute the task with frequent commits at meaningful checkpoints. 3. Present the result. 4. If the user rejects the result, revert to the pre-task commit.
    - **Follow-up**: Only on rejection: restore the pre-task state and confirm. No routine follow-up — this is infrastructure.
  - **Anti-patterns**: Never committing — makes all agent work irreversible; committing secrets or large generated artifacts into history; making changes that revert can't undo without manual cleanup.

**Decision — interactive single-agent**: Use **pair programming** when the task is exploratory or ambiguous. Switch to **plan-then-execute** once you can articulate what "done" looks like. Use **spec-driven** for features that cross multiple sessions or engineers. Use **TDD** for bug fixes, refactoring, or any work with an objective success criterion. Always use **checkpoint/rewind** as substrate. Avoid **vibe coding** for anything you'd deploy.

## Loops and autonomy

- **[Proven] Ralph (Ralph Wiggum loop)** — Geoffrey Huntley's brute-force pattern: run the same prompt in a `while` loop, fresh context each iteration, until the task is done. Trades tokens for reliability; the agent re-reads state each pass so it can't get stuck on its own stale context.
  - **Benefits**: Extremely simple and reliable — fresh context each iteration means the agent can't degrade from context decay; works when more sophisticated patterns fail; easy to implement.
  - **Trade-offs**: Token-costly — each iteration re-reads full state; no model improvement across iterations, it's pure retry; no feedback loop — each pass is independent, so the same mistake can repeat indefinitely.
  - **How to implement**: Put task items in a task file (e.g., `prd.json`) with pass/fail flags per item. The agent reads it each iteration, picks the first incomplete item, implements, verifies, flips the flag, commits, and exits. The loop re-invokes until all flags are true or the cap is hit. Always set a max iteration cap (10 is safe) and run in a fresh git worktree.
  - **Automation**:
    - **Requirements**: task items (list of sub-tasks), success criteria per item (testable), iteration cap (default 10), exit sentinel (e.g., "all items pass"). Must have a deterministic acceptance signal.
    - **Agent flow**: 1. Ask user to define task items with testable success criteria. If they can't, recommend evaluator-optimizer instead. 2. Set up the loop structure as described in How to implement. 3. Run the loop autonomously until all flags are true or the cap is hit. 4. Present results with the audit trail (each iteration's commit, what was done, test results).
    - **Follow-up**: Ask "does the output meet the criteria?" If not, diagnose — are the success criteria wrong? Did the loop hit the cap? Adjust and re-run.
  - **Anti-patterns**: Using when evaluator-optimizer would converge faster for the same cost; no exit condition — loops forever; not validating loop iteration quality.

- **[Unproven] Loop engineering** — The 2026 evolution of "I write loops now": authoring autonomous, scheduled agent-prompt programs with built-in verification and guardrails, treated as a discipline distinct from ad hoc prompting.
  - **Benefits**: More maintainable and testable than ad-hoc loops; treats prompts like code (version control, testing, refactoring); includes built-in verification and guardrails by design.
  - **Trade-offs**: Higher authoring overhead than ad-hoc loops; requires discipline and tooling; investment only pays off at ~5+ iterations of the same loop pattern.
  - **Automation**:
    - **Requirements**: loop purpose, schedule (if recurring), verification criteria. Must confirm this will run 5+ times.
    - **Agent flow**: 1. Ask if this loop runs 5+ times. If not, recommend ad-hoc Ralph loop. 2. Ask for the loop's purpose and verification criteria. 3. Help structure the loop as a version-controlled prompt program with guardrails, observability, and failure alerts. 4. Test on a sample run. 5. Commit and schedule. Check back after the first few runs.
    - **Follow-up**: After first 3 runs, ask "are results consistent? Any adjustments needed?"
  - **Anti-patterns**: Over-engineering a one-shot task into a loop program; brittle prompt programs that break on minor input variation; no observability into loop behavior in production.

- **[Proven] Evaluator-optimizer loop** — One agent generates, another critiques, repeat until the critic passes it. One of Anthropic's canonical workflow patterns. Differs from the audit loop: evaluator-optimizer regenerates the output each round against a fixed rubric; the audit loop fixes an existing work product in place with layered criteria per pass.
  - **Benefits**: Converges on quality — the evaluator catches what the generator misses; the evaluator judges the output, not the intent; complementary strengths between the two roles.
  - **Trade-offs**: 2× cost per iteration (generator + evaluator); needs a well-tuned critic prompt; iteration count is unpredictable and can be high if the evaluator is too strict.
  - **How to implement**: Use a **different model** for generator vs evaluator — a different family when available, otherwise a different tier or at minimum an independently prompted instance; the goal is uncorrelated blind spots. Give the evaluator a concrete rubric with pass/fail thresholds per criterion. Have the generator propose a sprint contract (a brief stating what it will build and how success is verified) before starting. Set a hard iteration cap (3-5) and escalate to human if hit.
  - **Automation**:
    - **Requirements**: output to generate, evaluation rubric (concrete criteria with pass/fail thresholds), iteration cap (default 3), model preference for each role (default: cheaper tier generates, stronger tier evaluates).
    - **Agent flow**: 1. Ask user what to generate and how to evaluate it. Help turn vague criteria into concrete rubric items. 2. Set up generator (produces output) and evaluator (scores against rubric). 3. Generator proposes a sprint contract — what it will build and how success is verified. Evaluator must approve before generation starts. 4. Loop: generate → evaluate → feedback → regenerate. 5. Stop when evaluator passes or cap is hit. Escalate to user if cap hit.
    - **Follow-up**: Present the final output with the evaluator's score and reasoning per rubric item. Ask "accept this, or adjust criteria and re-run?"
  - **Anti-patterns**: Using the same model in both roles — shared blind spots; evaluator rubber-stamps; no iteration cap — loops indefinitely.

- **[Proven] Audit loop** — Iteratively audit work: find issues, fix them, re-audit until N consecutive clean passes. Converges on quality instead of trusting a single review pass. Differs from evaluator-optimizer: the audit loop repairs an existing work product in place with different criteria per pass; evaluator-optimizer regenerates output each round against one fixed rubric.
  - **Benefits**: Each pass independently catches what the previous pass missed; converges on quality — N clean passes is a stronger signal than one; catches issues a single reviewer would skip.
  - **Trade-offs**: N passes minimum (N=2 recommended), so ~2-3× the review cost; can over-rotate on low-value issues while missing high-value ones if the audit prompt is poorly written.
  - **How to implement**: Structure the audit with layered checks — pass 1: logic correctness and edge cases. Pass 2: security, error handling, compliance. Pass 3: style, docs, conventions. Stop after N consecutive passes with zero findings.
  - **Automation**:
    - **Requirements**: work product to audit (code, doc, config), number of clean passes needed (default 2), risk tier (determines how many layers).
    - **Agent flow**: 1. Ask user what to audit and the risk tier. Higher risk = more passes. 2. Run pass 1 (logic, edge cases, correctness). Report findings. Fix them. 3. Run pass 2 (security, error handling, compliance). Report findings. Fix them. 4. Run pass 3 if needed (style, conventions, docs). 5. Stop after N consecutive passes with zero findings. Present the audit report: what was found per pass and how it was fixed.
    - **Follow-up**: Ask "review the audit report. Any passes you want re-run with different criteria?"
  - **Anti-patterns**: Auditing without fixing root cause; infinite loops on subjective criteria; stopping at N clean passes but the audit was shallow.

- **[Proven] Autonomous end-to-end process (gated phases)** — Run plan → implement → review as distinct phases, each with its own quality gate, fully hands-off. The structured replacement for raw "YOLO mode" autonomy.
  - **Benefits**: Fully hands-off execution; structured gates catch phase-level errors before they compound; phases provide natural checkpoints for human review if desired.
  - **Trade-offs**: Expensive (3–10× a guided session) because each phase re-reads state; if the plan is wrong, all downstream work compounds the error.
  - **How to implement**: Define phases upfront — Plan (research + spec), Implement (build one feature at a time), Review (audit + test), Secure (security audit). Each phase writes a structured handoff artifact. Each phase ends with a quality gate.
  - **Automation**:
    - **Requirements**: feature description, quality gate criteria per phase, notification preference (when to wake you vs. proceed).
    - **Agent flow**: 1. Ask user for the feature and quality gates. Agree on when to notify vs. proceed autonomously. 2. Execute Plan phase — research, produce spec, write handoff. Gate: spec approved. 3. Execute Implement phase — build from spec, one feature at a time. Gate: all tests pass. 4. Execute Review phase — audit and test the full output. Gate: zero critical findings. 5. Execute Secure phase (if needed). Present final result with handoff artifacts from each phase.
    - **Follow-up**: Present the full output with phase artifacts. Ask "review and approve? Any phase you want re-run?"
  - **Anti-patterns**: Skipping the review gate; no human-out-of-loop kill switch; using for tasks too small to amortize the phase overhead.

- **[Unproven] Loom (software factory)** — Huntley's follow-on to Ralph: a fuller orchestrator that runs the loop plus planning, task decomposition, and verification as a continuous factory. Differs from autonomous end-to-end (gated phases): Loom is a continuous loop with retries inside each task; gated phases run once through with a reviewable gate per phase.
  - **Benefits**: More capable than a raw loop — includes planning, decomposition, and verification as first-class stages; suitable for multi-step tasks.
  - **Trade-offs**: More complex to set up; overkill for tasks a simple Ralph loop would handle; requires observability into internal state.
  - **Automation**:
    - **Requirements**: overall feature description or task brief, success criteria, max iterations before escalation, preferred output format.
    - **Agent flow**: 1. Ask for the feature brief and acceptance criteria. 2. Plan phase — decompose the feature into tasks, produce a spec. 3. Loop phase — for each task, generate code, run tests, detect failure. On failure, feed error back into the loop with revised approach. 4. Verification phase — run all tests, lint, typecheck. 5. If max iterations exceeded without passing all gates, present partial results and ask whether to escalate. 6. Present final output with iteration log.
    - **Follow-up**: Show iteration count per task, test results, and final output. Ask "approve? retry failed tasks with adjusted instructions?"
  - **Anti-patterns**: Using Loom for tasks a simple Ralph loop or single agent would handle; running the factory without surfacing per-task iteration counts and failure reasons — when it thrashes you need to see where.

**Decision — loops and autonomy**: Use **Ralph** for well-scoped tasks with testable criteria. Use **evaluator-optimizer** when output quality needs iterative improvement. Use **audit loop** for security-sensitive or correctness-critical work. Use **autonomous end-to-end** for entire features you want without interaction. **Loop engineering** and **Loom** remain unproven — prefer the proven loops until they accumulate evidence.

## Multi-agent orchestration

- **[Proven] Subagent fan-out / orchestrator-workers** — A lead agent decomposes the task and dispatches parallel workers, each with its own fresh context window. The workhorse pattern for parallelizable work.
  - **Benefits**: Linear speedup on embarrassingly parallel work; fresh contexts per worker eliminate cross-contamination; scales across many workers.
  - **Trade-offs**: Coordination overhead from the orchestrator; each worker pays cold-start cost; massive context duplication if all workers re-read the same project state.
  - **How to implement**: The orchestrator writes a **task packet** per worker — a self-contained brief with exactly the files, spec, and context that worker needs. No worker should read more than ~20 files. Set a timeout per worker.
  - **Automation**:
    - **Requirements**: overall goal or explicit sub-task list, files/context per sub-task, number of workers, merge strategy (how to combine results).
    - **Agent flow**: 1. Ask user for the overall goal or explicit sub-tasks. If the user gives a goal, decompose it into independent sub-tasks and ask for confirmation. 2. Create a task packet per worker: files to read, spec, output location, timeout. 3. Dispatch workers in parallel. Monitor for timeouts and failures. 4. Collect results and merge according to the merge strategy. 5. Present merged result. If any worker failed, report what failed and whether to retry.
    - **Follow-up**: Ask "review the merged result. Any workers that need retry with adjusted context?"
  - **Anti-patterns**: Decomposing too finely — overhead exceeds parallelism gain; orchestrator bottleneck; not handling worker failures.

- **[Proven] Pipeline (prompt chaining)** — Fixed sequence of stages, each agent's output feeding the next. Use when the workflow shape is known and deterministic control flow beats model-driven control flow.
  - **Benefits**: Deterministic and debuggable — you know exactly which stage failed and why; easy to retry individual stages; predictable cost and latency.
  - **Trade-offs**: Rigid — later stages can't influence earlier ones; errors cascade silently; pipeline length adds latency.
  - **How to implement**: Each stage validates its output before passing to the next (schema check, test run, lint pass). Use structured artifacts (JSON) for handoffs. Keep pipelines short — 3-5 stages max.
  - **Automation**:
    - **Requirements**: list of stages in order, handoff format per stage (what passes between them), validation criteria per stage.
    - **Agent flow**: 1. Ask user to define the pipeline stages, handoffs, and validation per stage. 2. Set up the pipeline with validation gates between stages. 3. Execute stage 1, validate output. If validation fails, retry up to N times or stop. 4. Pass validated output to stage 2, repeat. 5. Present final output with a log of each stage's execution and validation result.
    - **Follow-up**: Ask "review the pipeline log. Any stage you want to retry with different parameters?"
  - **Anti-patterns**: Overly long pipelines where errors cascade; no recovery mid-pipeline; stages too coarse or too fine.

- **[Proven] Routing** — A classifier agent routes each input to a specialized handler (e.g., quick/standard/deep variants of the same role). Cheap requests stay cheap; hard ones get the heavyweight treatment.
  - **Benefits**: Saves ~40–70% cost on mixed-difficulty workloads; handlers are specialized for their input type.
  - **Trade-offs**: Single point of failure in the router; classification errors cause quality or cost failures.
  - **Automation**:
    - **Requirements**: request categories, handler definitions per category (model tier, prompt, tools), fallback handler for low-confidence classifications.
    - **Agent flow**: 1. Ask user to define categories and handlers. 2. Set up classifier agent that categorizes each incoming request. 3. Route to the appropriate handler. 4. If classifier confidence is below threshold, route to fallback or ask user. 5. Log routing decisions for audit and improvement.
    - **Follow-up**: Periodically ask "review routing decisions. Any misclassifications we should fix?"
  - **Anti-patterns**: Router misclassifying hard tasks as easy — silent quality failure; no fallback when confidence is low.

- **[Proven] Supervisor pattern** — A persistent manager agent monitors, assigns, and re-plans over a pool of workers. Widely cited as the production default for long-running multi-agent work.
  - **Benefits**: Dynamic re-planning adapts to changing requirements mid-task; persistent state builds task-specific expertise; best for long-running work.
  - **Trade-offs**: Supervisor context grows unboundedly without compaction; supervisor can become a bottleneck.
  - **How to implement**: The supervisor's job is to re-plan, not just dispatch. Give it a narrow charter (5 paragraphs max). Workers get a scoped task packet. Compact supervisor context every 5-10 cycles. Start with 3 workers.
  - **Automation**:
    - **Requirements**: long-running goal, authority boundaries (what the supervisor can decide autonomously vs. escalate), number of workers (default 3).
    - **Agent flow**: 1. Ask user for the goal and boundaries. What decisions can the supervisor make alone? What requires escalation? 2. Set up supervisor with a narrow charter and worker pool. 3. Supervisor decomposes the goal, dispatches tasks, reviews results, re-plans. 4. Supervisor compacts its context every 5-10 cycles. 5. If a worker fails the same task twice, supervisor tries a different approach. If it can't resolve, escalate to user.
    - **Follow-up**: Periodically present progress summary. Ask "any adjustments to boundaries or priorities?"
  - **Anti-patterns**: Supervisor becomes bottleneck; context grows without compaction; treating supervisor as a simple router.

- **[Proven] Best-of-N + judge (tournament)** — Generate N independent solutions from different angles, have judge agents score them, synthesize from the winner. Costs ~2.5× a single run.
  - **Benefits**: Dramatically better coverage of the solution space; judge provides objective scoring; best for creative/design tasks.
  - **Trade-offs**: Independence is hard to guarantee — correlated solutions waste the cost; judge bias toward style or length.
  - **How to implement**: Give each worker a different angle in its prompt. Use different model families. Score on multiple criteria. Don't just take the winner — synthesize the best parts of each approach. Use hybrid tier: cheap models for N-1 workers, premium model as judge.
  - **Automation**:
    - **Requirements**: problem to solve, evaluation criteria (multiple dimensions), number of solutions N (default 3), angles for each worker (or let agent suggest diverse angles).
    - **Agent flow**: 1. Ask user for the problem and evaluation criteria. Suggest angles if they don't have them. 2. Spawn N workers each with a different angle, different model family if possible. 3. Run judge agent that scores each solution on all criteria. 4. Extract the best parts of each approach and synthesize a final solution. 5. Present the scores, each solution's strengths/weaknesses, and the synthesized result.
    - **Follow-up**: Ask "does the synthesized solution meet your needs? Any specific approach you want to explore further?"
  - **Anti-patterns**: Correlated solutions; judge bias; winner-take-all discarding useful insight from non-winners.

- **[Proven] Adversarial verification / multi-agent debate** — Spawn independent skeptics prompted to refute each finding or claim; only majority-surviving results count.
  - **Benefits**: Effectively kills plausible-but-wrong output; majority voting provides strong signal; best when false positives are expensive (security, compliance).
  - **Trade-offs**: 2-3× cost; can over-reject correct but unconventional output.
  - **How to implement**: Prompt adversarial agents with a specific claim to refute. Use hybrid tier: cheap models enumerate (high recall), one premium model adjudicates. Run 3-5 agents from different model families when available; within a single model family, get diversity from distinct refutation angles, prompts, and effort tiers instead. Define "refuted" upfront.
  - **Automation**:
    - **Requirements**: claim or output to verify, definition of "refuted" (what would prove the claim wrong), number of adversarial agents (default 3).
    - **Agent flow**: 1. Ask user for the claim and what "refuted" means. 2. Spawn 3-5 adversarial agents, each prompted to refute the specific claim from a distinct angle (different model families when available). 3. Run a judge agent that evaluates the debate: did a majority successfully refute the claim? 4. Document why each surviving claim passed (what counterexamples were attempted and why they failed). 5. Present verdict with full debate transcript and reasoning.
    - **Follow-up**: Ask "do you accept the verdict? Any agents you want to re-prompt with different refutation angles?"
  - **Anti-patterns**: Agents that refuse to agree on anything — all output fails; adversarial agents that are just contrarian; using for subjective tasks with no ground truth.

- **[Proven] LLM-as-judge / agent-as-judge** — Use an agent to evaluate outputs against a rubric, at scale. The 2026 variant observes the full action trace, not just the final artifact.
  - **Benefits**: Scalable evaluation — one judge can score hundreds of outputs; per-step trace catches process errors; replaces expensive human evaluation.
  - **Trade-offs**: Eval awareness undermines validity; rubric quality determines judge quality; judge may rubber-stamp based on surface features.
  - **How to implement**: Choose scoring mode by use case — pointwise for dashboards, pairwise for release decisions, reference-based when ground truth exists. Use a different model family than the one evaluated. For high-stakes calls, run a 3-model cross-family ensemble. Calibrate first: hand-label 30-50 examples, iterate rubric until Cohen's kappa ≥ 0.6.
  - **Automation**:
    - **Requirements**: outputs to evaluate, evaluation rubric (criteria + scale), ground truth labels for calibration (30-50 examples), scoring mode (pointwise/pairwise/reference-based).
    - **Agent flow**: 1. Ask user for the outputs, rubric, and calibration data. If no calibration data exists, ask them to label 30-50 examples. 2. Calibrate the judge: score calibration set, compare to human labels, iterate rubric until agreement is acceptable. 3. Score the full set of outputs with reasoning per score. 4. For high-stakes evaluations, run a cross-model ensemble. 5. Present aggregate scores, score distributions, and reasoning for outlier scores.
    - **Follow-up**: Ask "review the results. Any drift to investigate? Keep a 5-10% re-grade sample running."
  - **Anti-patterns**: Using eval-aware models as judges without mitigation; vague rubrics; judge rubber-stamping based on surface features.

- **[Niche] Agent swarms / fleets** — Dozens-to-hundreds of agents on one goal: hierarchical orchestrators, shared work ledger, git-merge conflict resolution. Notable: Anthropic's reported C-compiler build (~16 agents, ~$20K, ~2 weeks).
  - **Benefits**: Massive parallelism for goals too large for any single agent session; self-assignment eliminates centralized dispatch; specialized roles bring expertise.
  - **Trade-offs**: Extremely complex orchestration; high total token cost; significant infrastructure overhead; publicized seven-figure failure cases exist.
  - **How to implement**: Do not start here. Begin with a single agent, then fan-out, then supervisor. Only graduate to swarms when smaller patterns bottleneck. Use git-based coordination (lock files, agent-specific branches). Each agent in its own container. The test suite is the real orchestrator.
  - **Automation**:
    - **Requirements**: complex goal that has already bottlenecked on fan-out and supervisor. Significant budget ($5K+). Infrastructure for containers and git coordination.
    - **Agent flow**: 1. Ask user if they've already tried smaller patterns and confirmed they bottleneck. If not, start there. 2. If confirmed, set up git-based coordination with lock files and containers. 3. Agents self-assign work from a shared ledger. 4. Monitor for conflict resolution issues and agent thrashing. 5. Present results with conflict resolution log and merge status.
    - **Follow-up**: Expect high cost and complexity. After run, ask "was the benefit worth the overhead? Consider whether a supervisor or fan-out would have sufficed."
  - **Anti-patterns**: Premature swarm adoption; missing conflict resolution; no shared work ledger.

- **[Proven] Git-worktree parallelism** — Each agent works in its own worktree of the same repo, so parallel agents can't trample each other; merge at the end.
  - **Benefits**: Eliminates file-level trampling; per-agent DB/port isolation prevents resource conflicts; merge at the end provides a single integration point.
  - **Trade-offs**: Merge effort scales with divergence; isolation adds infrastructure overhead; no communication between agents during work.
  - **How to implement**: Assign each agent its own `git worktree add`. Use Docker with unique port mappings per agent. Keep sessions short (under 1 hour). Use a shared `INTERFACE_CHANGES.md` for agents to communicate API contract changes.
  - **Automation**:
    - **Requirements**: sub-tasks for parallel execution, expected duration, DB/port isolation needs.
    - **Agent flow**: 1. Ask user for the sub-tasks and isolation requirements. 2. Create a worktree per agent with isolated DB ports and environment. 3. Create `INTERFACE_CHANGES.md` for coordination. 4. Agents work in parallel. Monitor for conflicts. 5. After all complete, merge sequentially and run the full test suite on the merged result. Report any merge conflicts.
    - **Follow-up**: Ask "review the merge result. Frequent conflicts mean decomposition was too coarse."
  - **Anti-patterns**: Long-running branches that diverge too far; no communication about shared interface changes; treating isolation as a substitute for decomposition planning.

**Decision — multi-agent orchestration**: Use **fan-out** for embarrassingly parallel work. Use **pipeline** when the workflow is a known sequence. Use **routing** for mixed-difficulty request streams. Use **supervisor** for long-running adaptive tasks. Use **tournament** for design/creative work. Use **adversarial debate** when false positives are expensive. Use **LLM-as-judge** for scalable evaluation. Use **swarms** only when smaller patterns bottleneck. Always use **git-worktree parallelism** for concurrent agents on the same repo.

## Background and automation

- **[Proven] Background / cloud agents** — Fire-and-forget: hand off a task, agent works asynchronously and comes back with a PR. Best for well-scoped tasks that don't need mid-flight steering.
  - **Benefits**: Async turnaround — you hand off and return to a completed PR; frees your time for work that requires human judgment.
  - **Trade-offs**: No ability to steer once launched; results come back in minutes to hours; cloud agents lack local context.
  - **How to implement**: Use a completeness checklist before launching — files to change, success criteria, files NOT to touch, context needed. Start with low-risk tasks.
  - **Automation**:
    - **Requirements**: task spec (must include: files to change, success criteria, files NOT to touch, context to attach), risk tier (determines auto-merge vs. human review policy).
    - **Agent flow**: 1. Ask user for the task spec. Check against completeness checklist. If gaps exist, fill them before launching. 2. Confirm: "the spec is complete. I'll run this asynchronously and come back with a PR." 3. Launch the cloud agent with the spec. 4. When the PR is ready, present the diff and test results. 5. If risk tier is low and trust is established, offer to auto-merge. Otherwise, wait for human review.
    - **Follow-up**: Ask "review the PR. Merge, request changes, or discard?"
  - **Anti-patterns**: Fire-and-forget on ambiguous tasks; no verification of the result before merging; assuming cloud agents have the same context as local.

- **[Proven] Scheduled / cron agents (routines)** — Agents that run on a schedule: nightly dependency audits, morning triage, recurring reports.
  - **Benefits**: Autonomous recurring work — set it and forget it; runs outside human working hours; ideal for maintenance tasks.
  - **Trade-offs**: Failure detection and alerting required — if the agent errors silently, you lose that run's work.
  - **Automation**:
    - **Requirements**: task definition, schedule (cron expression or natural language), alerting channel (Slack, email, etc.), read-only vs. write mode.
    - **Agent flow**: 1. Ask user for the task, schedule, and alerting preferences. Default to read-only mode for audit tasks. 2. Set up the cron trigger. 3. Configure alerting on failure and success/failure reporting. 4. Test-run the first execution immediately to verify it works. 5. Leave running. Check alerts after first few runs.
    - **Follow-up**: After first 3 executions, ask "review the results. Any adjustments to the task or schedule?"
  - **Anti-patterns**: No alerting on failure; expensive daily runs when state hasn't changed; the agent making unauthorized changes.

- **[Proven] Agent-in-CI** — Agents wired into the development pipeline: `@claude` mentions on issues/PRs, automatic PR review, auto-fix of failing builds.
  - **Benefits**: Fits existing workflow — no separate chat tool; agent has full PR context; automates review and fix within the pipeline.
  - **Trade-offs**: CI pipeline may need restructuring for agent round-trips; agent actions carry risk if not tightly scoped.
  - **How to implement**: Start with read-only agent roles — PR review, security triage, test failure analysis. Only add write actions after trust is built. Use risk-tier labels. Guard against CI loops.
  - **Automation**:
    - **Requirements**: CI platform (GitHub Actions, etc.), agent actions per event (PR opened, build failed, etc.), risk tiers for auto-merge policy.
    - **Agent flow**: 1. Ask user what CI events should trigger the agent and what actions to take per event. 2. Start with read-only actions: review PRs, comment on failures, triage issues. 3. After trust is built, add write actions for low-risk tiers: auto-fix formatting, auto-merge dependency updates. 4. High-risk tiers always require human merge. 5. Verify the agent cannot trigger itself (no infinite CI loops).
    - **Follow-up**: Periodically ask "review the agent's CI actions. Any false positives or missed issues?"
  - **Anti-patterns**: Agent making CI-flaky changes that loop CI; overly permissive agent actions in CI; agent review being the only review.

- **[Niche] Event-triggered automations** — Always-on agents fired by external events (GitHub webhooks, Slack messages) rather than schedules or mentions.
  - **Benefits**: Responsive — fires within seconds of the triggering event; enables real-time workflows.
  - **Trade-offs**: Always-on cost; larger security surface due to external input; event storms can cascade.
  - **Automation**:
    - **Requirements**: event source (webhook, Slack command, etc.), event → action mapping, rate limits, security validation (how to verify event authenticity).
    - **Agent flow**: 1. Ask user for event source and action mapping. 2. Set up webhook receiver with input validation and authenticity verification. 3. Configure rate limiting to prevent event storms. 4. Add guardrail against recursive trigger loops. 5. Test with a controlled event before enabling always-on.
    - **Follow-up**: After first day, ask "review the event log. Any unexpected triggers or loops?"
  - **Anti-patterns**: Recursive trigger loops; no input validation leading to injection attacks; no rate limiting.

- **[Niche] Headless / Agent SDK pipelines** — Drive the agent programmatically (Claude Agent SDK, `claude -p`) to build your own tools: batch processing, custom review bots, bespoke orchestrators.
  - **Benefits**: Full control over agent lifecycle, input, and output processing; enables custom workflows no off-the-shelf tool provides.
  - **Trade-offs**: Requires integration effort and ongoing maintenance; you must handle errors, rate limits, and output parsing.
  - **Automation**:
    - **Requirements**: workflow description, integration language (Python, TypeScript, etc.), error handling preferences, output parsing requirements.
    - **Agent flow**: 1. Ask user for the workflow and integration context. 2. Provide a starter integration using the Agent SDK with error handling, rate limiting, and structured output parsing. 3. Help test the integration with a sample workflow. 4. Commit the integration code. 5. Leave documentation for maintenance.
    - **Follow-up**: Ask "test the integration with a real workflow. Any edge cases to handle?"
  - **Anti-patterns**: Reimplementing what native tools already provide; not handling agent errors or rate limits; brittle output parsing.

- **[Unproven] Managed Agents (brain/hands decoupling)** — Anthropic's 2026 architecture: stateless harness + durable external session log, `wake(sessionId)` recovery, elastic scaling.
  - **Benefits**: Sessions survive infrastructure failures; elastic scaling of models and executors independently.
  - **Trade-offs**: Session log grows without bound; infrastructure complexity is high.
  - **Automation**:
    - **Requirements**: this is an architectural pattern, not a directly executable workflow. If user asks for long-running resilient agents, recommend background/cloud agents or agent-in-CI instead.
    - **Agent flow**: 1. Explain that this is an infrastructure architecture, not a workflow pattern. 2. If user needs long-running resilient agents, help them set up background/cloud agents or agent-in-CI. 3. If they insist, provide the concept: stateless harness + durable session log + wake(sessionId) recovery.
    - **Follow-up**: None — this is infrastructure design, not a workflow.
  - **Anti-patterns**: Session log bloat; over-provisioning executors; relying on recovery without testing it.

- **[Unproven] Agent command centers** — Kanban-style boards for monitoring fleets of concurrent agents, plus the Agent Client Protocol (ACP) for driving different vendors' agents from one editor.
  - **Benefits**: Visibility across agents, projects, and vendors from a single pane of glass.
  - **Trade-offs**: Dashboard overhead — someone must watch it; vendor lock-in risk.
  - **Automation**:
    - **Requirements**: number of concurrent agents (if <5, don't need this), agent vendors in use, monitoring preferences.
    - **Agent flow**: 1. Ask how many concurrent agents they run. If <5, explain they don't need this yet. 2. If they're at scale, describe options: Devin Command Center, ACP-compatible tools. 3. Help them set up basic monitoring (export logs, basic dashboard) before investing in a full command center.
    - **Follow-up**: Ask "is the basic monitoring sufficient? Only invest in a command center if you're managing 10+ concurrent agents."
  - **Anti-patterns**: Dashboard without action — monitoring failures without a response plan; vendor lock-in.

**Decision — background and automation**: Use **background/cloud agents** for well-scoped async tasks. Use **scheduled agents** for recurring maintenance. Use **agent-in-CI** for PR and build automation. Use **event-triggered** for responsive workflows. Use **headless/SDK** for custom integrations.

## Context and memory

- **[Proven] Memory files (CLAUDE.md / AGENTS.md)** — Persistent project instructions the agent loads every session: conventions, commands, gotchas. The highest-leverage, cheapest improvement to agent output quality.
  - **Benefits**: Highest leverage — influences every agent session for the cost of writing it once; eliminates repeating instructions; encodes project knowledge the agent can't infer from code alone.
  - **Trade-offs**: Must be maintained — stale instructions cause confidently wrong behavior; takes discipline to update when conventions change.
  - **Automation**:
    - **Requirements**: project structure, language/framework, key conventions, build/test commands. Optionally: existing memory file to review.
    - **Agent flow**: 1. Ask if they have existing memory files. If yes, review for accuracy and completeness. 2. If no, ask about project structure, conventions, and commands. 3. Draft or update CLAUDE.md with sections: project overview, conventions, commands, common gotchas, architecture notes. 4. Present for review. 5. Once approved, it will be loaded every session. Remind them to update it when conventions change.
    - **Follow-up**: Periodically ask "has anything changed since we wrote the memory file? Should we update it?"
  - **Anti-patterns**: Stale instructions — worse than none; adding everything — long files dilute critical info; contradictions between multiple memory files.

- **[Proven] Skills / slash commands** — Reusable procedural knowledge packaged as on-demand instructions (SKILL.md). Teach the agent a workflow once, invoke it forever.
  - **Benefits**: Reusable — one definition, infinite uses; on-demand loading means zero context overhead when not invoked.
  - **Trade-offs**: Skills must be well-scoped — too broad and they become memory files; too narrow and there are too many to remember.
  - **Automation**:
    - **Requirements**: workflow description (what steps does it involve?), trigger (how do you want to invoke it — slash command, file name?).
    - **Agent flow**: 1. Ask user what workflow they want to encode as a skill. 2. Help scope it — should be one focused procedure, not a general reference. 3. Write the skill file with clear trigger, steps, and expected inputs/outputs. 4. Test by invoking it. 5. Refine based on what the agent misses.
    - **Follow-up**: Ask "does the skill produce the expected output? Any steps to add or clarify?"
  - **Anti-patterns**: Overly broad skills that should be memory files; skills that assume context the agent doesn't have at invocation.

- **[Proven] Custom subagents** — Predefined agent roles with their own system prompt, tool set, and model tier (reviewer, debugger, researcher…).
  - **Benefits**: Specialist quality beats generalist on narrow tasks; consistent behavior; appropriate model tier per task.
  - **Trade-offs**: Configuration overhead per agent; catalog can grow large; prompts must be updated when conventions change.
  - **Automation**:
    - **Requirements**: role description (reviewer, debugger, etc.), tools it needs (read-only, write, etc.), model tier preference (cheap vs. capable).
    - **Agent flow**: 1. Ask user what specialist role they need. 2. Define the subagent with a focused system prompt, restricted tool set, and model tier. 3. Test on a sample task. 4. Refine the prompt based on output quality. 5. Commit the subagent definition so it's available in future sessions.
    - **Follow-up**: Ask "does the subagent perform the role well? Any adjustments to its prompt or tools?"
  - **Anti-patterns**: Too many narrow agents — catalog becomes unmanageable; overlapping responsibilities leading to inconsistent routing.

- **[Proven] Context compaction / structured handoff** — Summarize a long session into a handoff note so work continues past the context window.
  - **Benefits**: Enables arbitrarily long sessions by compressing what's known; structured handoff preserves what matters most.
  - **Trade-offs**: Compaction is lossy — detail, rationale, rejected alternatives may be dropped; the handoff quality determines how much work carries forward.
  - **How to implement**: Structure the handoff as: what was done, what's next, decisions made, rejected approaches, codebase state. Keep it under 200 lines. Review the handoff before the next phase starts.
  - **Automation**:
    - **Requirements**: current session state (what's been done, what's pending, decisions made, rejected approaches). The agent can extract this from the conversation.
    - **Agent flow**: 1. Detect when context window is getting full or user requests a handoff. 2. Extract: completed items, pending items, key decisions with rationale, approaches rejected and why, current codebase state. 3. Compress into a structured handoff under 200 lines. 4. Present for user review — confirm nothing critical was dropped. 5. Load the handoff in the next session.
    - **Follow-up**: Ask "does this handoff capture everything important? Any decisions or context I missed?"
  - **Anti-patterns**: Compacting too aggressively — losing critical decisions; relying on compaction instead of fitting the task in one window; not reviewing the handoff.

- **[Niche] Harness design with context resets** — Deliberately reset context at phase boundaries with structured handoff artifacts instead of one ever-growing conversation. Differs from context compaction: compaction rescues a session already running out of window; harness resets are planned boundaries designed in from the start.
  - **Benefits**: Clean phase boundaries with fresh reasoning capacity each phase; prevents context degradation over long builds.
  - **Trade-offs**: More complex orchestration; handoff artifact quality is the critical path — a bad handoff loses the work.
  - **Automation**:
    - **Requirements**: phase definitions (what each phase produces and what it needs from the previous one), handoff artifact format.
    - **Agent flow**: 1. Ask user to define the phases and what each produces. 2. For each phase, define the handoff artifact: what the previous phase must leave, what this phase needs. 3. Execute phases sequentially with context reset between each. 4. Present handoff artifacts for user validation between phases. 5. If a handoff is rejected, re-run the previous phase with corrections.
    - **Follow-up**: After each phase, ask "review the handoff artifact. Ready for the next phase?"
  - **Anti-patterns**: Losing state between phases because handoff was incomplete; wrong phase boundaries — splitting where continuity matters.

**Decision — context and memory**: Start with **memory files (CLAUDE.md)** — highest-leverage single thing you can do. Add **skills** for recurring workflows. Add **custom subagents** for repeated specialist roles. Use **context compaction** when sessions exceed the context window. Use **harness context resets** for autonomous builds spanning multiple phases.

## Tooling, verification, and guardrails

- **[Proven] MCP (Model Context Protocol) tools** — Standard way to give agents new capabilities: databases, browsers, SaaS APIs, internal services.
  - **Benefits**: Drastically extends agent capabilities — an agent with DB access can migrate schemas, a browser agent can test UIs; standard protocol means tools are portable.
  - **Trade-offs**: Each MCP server is a security boundary and dependency; over-privileged access magnifies risk.
  - **Automation**:
    - **Requirements**: capability needed (DB type, browser, API, etc.), access level required (read-only vs. read-write), endpoint/connection details.
    - **Agent flow**: 1. Ask user what capability the agent needs and at what access level. Default to read-only. 2. Configure the MCP server connection with minimum required privileges. 3. Test the connection with a simple operation. 4. Verify the agent can use the tool correctly. 5. Document the MCP server as a dependency.
    - **Follow-up**: Ask "test the tool. Is the access level appropriate? Any rate limits to configure?"
  - **Anti-patterns**: Over-privileged tool access — write when read-only suffices; no rate limiting; depending on MCP servers that change without notice.

- **[Proven] Hooks as deterministic guardrails** — Lifecycle hooks (pre/post tool use, on stop) that run real code: auto-format after edits, block dangerous commands, enforce checks.
  - **Benefits**: Deterministic — hooks always run, the model can't bypass them; ideal for enforcing invariants.
  - **Trade-offs**: Adds complexity to agent setup; hooks that fail can block legitimate actions; hooks with invisible side effects confuse the agent.
  - **Automation**:
    - **Requirements**: invariants to enforce (formatting rules, blocked commands, required checks), actions to take when violated (block, warn, auto-fix).
    - **Agent flow**: 1. Ask user what invariants they want to enforce. 2. Configure hooks: pre-hooks block dangerous actions, post-hooks auto-format and verify. 3. Test with a legitimate action and a blocked action. 4. Ensure failing hooks stop execution (never fail silently). 5. Document the hooks so the agent knows they exist and can anticipate their effects.
    - **Follow-up**: Ask "do the hooks block legitimate work or allow dangerous actions? Adjust as needed."
  - **Anti-patterns**: Hooks that silently fail; overly restrictive hooks that block legitimate actions; hooks with invisible side effects the agent can't anticipate.

- **[Niche] Auto mode (classifier-gated permissions)** — Input-injection screening plus output action-safety classification, with graduated permission tiers. Autonomy without the blank check.
  - **Benefits**: Safer than blanket permissions; graduated tiers provide appropriate autonomy per task.
  - **Trade-offs**: Classifier can be wrong (false positive blocks work, false negative allows harm).
  - **Automation**:
    - **Requirements**: permission tier for the task (read-only, edit, execute, deploy). Relies on the tool's built-in classifier.
    - **Agent flow**: 1. Ask user for the appropriate permission tier for the task. 2. The classifier screens inputs and outputs against the tier. 3. If a dangerous action is blocked, inform the user and explain why. 4. If the block was legitimate, suggest an alternative approach. If it was a false positive, ask the user to override. 5. Review classifier decisions periodically.
    - **Follow-up**: Ask "review any blocked actions. Were they correctly blocked or false positives?"
  - **Anti-patterns**: Trusting the classifier completely; ignoring false negatives; using auto mode to skip human review.

- **[Niche] Environment-first containment** — Sandbox the agent deterministically (containers, egress-control proxies) rather than relying on the model to refuse bad actions.
  - **Benefits**: Strongest defense — works even if the model is compromised or jailbroken; defense in depth.
  - **Trade-offs**: Adds setup complexity and resource overhead; misconfigured containers provide false confidence.
  - **Automation**:
    - **Requirements**: agent access requirements (which files, network, APIs), security constraints (no egress, no production, etc.).
    - **Agent flow**: 1. Ask user what the agent needs to access and what should be blocked. 2. Configure container isolation: network policy (default deny, allow specific), filesystem (read-only for protected paths), resource limits. 3. Configure egress control proxy. 4. Test that legitimate actions work and malicious ones are blocked. 5. Document the containment setup.
    - **Follow-up**: Ask "test with a real task. Does the containment block any legitimate actions or allow any dangerous ones?"
  - **Anti-patterns**: Leaky containers — agent escapes via mounted sockets or network access; allowing egress without inspection; assuming containerization alone is sufficient.

- **[Proven] Self-verification (verify-before-done)** — Agent must exercise its change end-to-end — run the app, drive the flow, observe behavior — not just pass typecheck/tests.
  - **Benefits**: End-to-end confidence — the feature actually works, not just compiles; catches integration issues and runtime errors.
  - **Trade-offs**: Time cost — running the app is slower than static checks; requires a runnable environment.
  - **How to implement**: The agent must actually run the app, not simulate it. Provide a way to spin up the full stack. Verification should include: build, existing tests, new tests, manual exercise, error paths.
  - **Automation**:
    - **Requirements**: run command or docker compose setup, test command, manual exercise steps (API calls, UI flow, CLI invocation).
    - **Agent flow**: 1. Ask user how to run the app and tests. If no runnable environment exists, create one (docker compose, script). 2. Run build and existing tests to establish baseline. 3. Make changes. 4. Run build, all tests, and manually exercise the feature (API call, UI flow, error path). 5. Present evidence: build output, test results, and description of manual verification. Re-verify after every significant edit.
    - **Follow-up**: Ask "review the verification evidence. Is the feature working correctly? Any edge cases I missed?"
  - **Anti-patterns**: Trivial verification — simulating instead of executing; only testing the happy path; not re-verifying after the last edit.

- **[Proven] Computer use / browser agents** — Agent drives a real GUI or browser (screenshots + clicks, or Playwright via MCP) to test UIs, fill forms, reproduce bugs.
  - **Benefits**: Tests what users actually see — catches visual regressions, layout bugs, and interaction flows that unit tests miss.
  - **Trade-offs**: Slow — screenshot → act → screenshot cycle is orders of magnitude slower than API tests; fragile — CSS changes break selectors.
  - **How to implement**: Reserve for visual workflows only. Use `data-testid` attributes instead of CSS selectors. Wait for specific elements to appear. Set a max step limit per session (e.g., 30).
  - **Automation**:
    - **Requirements**: UI flow to test or bug to reproduce, URL or local setup, selectors strategy (data-testid preferred).
    - **Agent flow**: 1. Ask user what UI flow to test. Prefer `data-testid` selectors over fragile CSS selectors. 2. Start the app or navigate to the URL. 3. Step through the flow: take screenshot, perform action, wait for next state, repeat. 4. Report what happened at each step and whether it matches expectations. 5. Set a max step limit (default 30) to prevent runaway token burn.
    - **Follow-up**: Ask "does the behavior match what you expected? Any specific states or flows to re-test?"
  - **Anti-patterns**: Using browser agents for everything when API/unit tests would be faster; brittle selectors; not handling async UI states.

**Decision — tooling and guardrails**: Use **MCP** to give agents capabilities. Use **hooks** to enforce invariants. Use **auto mode** for graduated autonomy. Use **environment-first containment** for sensitive systems. Use **self-verification** always. Use **computer use** for UI testing.

## Foundational building blocks (underlying everything)

- **[Proven] ReAct (reason + act)** — Interleave reasoning steps with tool calls. The core loop inside every modern agent; you don't implement it anymore, but every pattern above is built on it.
  - **Benefits**: Universal substrate — every agent framework implements ReAct under the hood; you never need to build it yourself.
  - **Trade-offs**: The quality of the reasoning step determines tool choice quality; ReAct adds token overhead for the reasoning trace.
  - **Automation**: Not a user-invocable pattern. This is an implementation detail inside every agent. If you're debugging agent behavior, look at the reasoning trace to understand tool choice.
  - **Anti-patterns**: Trying to implement ReAct yourself — you'll get a worse version; not understanding it when debugging agent behavior.

- **[Niche] Reflexion / self-critique** — Agent reviews its own output before finalizing. Academically studied and built into most agent products as a cheap first-pass filter, but the weakest form of verification — same model, same blind spots.
  - **Benefits**: Cheap — no additional agent call if the same model self-reviews; catches typos, missing imports, obvious contradictions.
  - **Trade-offs**: Same blind spots as the original generation; only catches surface-level issues, not deep logical errors.
  - **Automation**: Not a user-invocable pattern. This runs automatically as a cheap first filter in most agents. For anything important, use evaluator-optimizer or adversarial verification instead.
  - **Anti-patterns**: Relying on self-critique as the only verification for anything important; assuming "the agent reviewed itself" means the output is verified.

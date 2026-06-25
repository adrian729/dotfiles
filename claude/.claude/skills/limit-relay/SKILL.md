---
name: limit-relay
description: >-
  Use before or during a task you judge heavy/long (big refactor, multi-file edit, long audit,
  batch generation, deep research): reads the cached 5h ("hourly") usage window and, if the task
  won't fit before it resets, checkpoints and auto-resumes in THIS session after the reset. Skip
  for small/quick tasks — they fit and checking wastes tokens.
---

## When
Check before a heavy/long task, after a heavy mid-session prompt, and at clean checkpoints during a
long task (catches underestimates). Never for small/quick tasks.

## 1. Read (cheap)
`cat /tmp/statusline-rate-limits` → `HOURS|WEEK|HOURS_RESET|WEEK_RESET` (HOURS/WEEK = used %).
`remaining = 100 - HOURS`.
- missing/empty → skip silently (no data; don't seek alternatives).
- `now >= HOURS_RESET` → already reset; treat `remaining` as 100%.

## 2. Decide
- `remaining >= ~50%` → proceed, say nothing.
- else, by your task-size estimate: small → proceed; medium/heavy or HOURS very high → §3.
- if WEEK also very high → tell the user, do NOT arm (an hourly reset won't clear a weekly cap).

## 3. Relay
1. One short line to the user, e.g. `⏳ may hit 5h limit (~HH:MM, NN% used); checkpointing + auto-continuing here after reset — keep session open`.
2. Immediately (a heavy step could burn the rest first):
   - Write `relay-handoff.md` to your scratchpad dir, self-contained to resume cold: task, done, next steps, files touched.
   - Arm resume via run_in_background, noting its task id: `sleep $(( HOURS_RESET - $(date +%s) + 60 ))`. If HOURS_RESET is past, don't arm; just proceed.
3. Work, keeping `relay-handoff.md` current at each checkpoint.
4. Finish before reset → delete `relay-handoff.md`, THEN stop the armed sleep.
5. Cut off / sleep fires → on re-invoke: read `relay-handoff.md`, redo §1–2, continue; if still short re-arm to current HOURS_RESET; repeat per window until done, then delete it.
6. On any re-invoke with `relay-handoff.md` missing → do nothing.

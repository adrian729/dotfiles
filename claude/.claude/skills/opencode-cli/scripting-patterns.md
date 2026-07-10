## Scripting patterns — extended reference

```sh
# One-shot query, JSON output
opencode run --format json "Explain closures in JavaScript" | jq .

# Pipe content
cat build.log | opencode run --format json "Extract every error with file:line"

# With specific provider/model
opencode run -m opencode/deepseek-v4-flash-free --format json "Summarize this"

# Headless task agent in specific directory, auto-approve
opencode run --agent task --dir /workspace --auto "Refactor module" --format json

# Continue a specific session
opencode run -s <sessionID> --format json "Follow up"

# Attach to running server (avoids cold-start overhead)
opencode run --attach http://localhost:4096 --format json "Quick task"

# Attach file to prompt
opencode run -f src/main.rs "Review this file for bugs"

# With reasoning effort variant
opencode run --variant high "Solve this problem" --format json

# List sessions programmatically
opencode session list --format json

# Minimal interactive
opencode --mini --prompt "Walk me through the architecture"
```

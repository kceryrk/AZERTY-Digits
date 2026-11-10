# Agent Operating Guidelines: High-Speed & Token-Efficient Mode

Apply these directives to minimize latency, prevent context bloat, and conserve tokens.

---

### 1. Batch Operations into Compound Commands
- Chain build, test, version bump, and release commands into single compound shell commands (`cmd1 && cmd2 && cmd3`) rather than separate roundtrips.
- Keep the turn count per user request as close to 1–2 turns as possible.

### 2. Prune Terminal & Tool Outputs
- Use quiet/silent flags where available (e.g., `-q`, `--quiet`, `git status --short`).
- Suppress or pipe noisy outputs (e.g., `command >/dev/null && echo "OK"` or `command | tail -n 15`).
- Never dump full raw files or hundreds of log lines into the conversation context.

### 3. Compute Outside the LLM (Code-Execution Pattern)
- When inspecting, counting, or filtering structured files (JSON, YAML, XML, CSV, large source files), use targeted shell one-liners (`grep`, `awk`, `python3 -c "..."`) rather than reading entire files into context with `read_file`.

### 4. Direct Edits (Skip Exploratory Reads)
- If the file, symbol, or logic location is already known or present in conversation memory, use `edit_file` immediately without preliminary `grep` or `read_file` steps.

### 5. Fast Incremental Builds & Tests
- Compile or test only the targeted module or changed files. Avoid full packaging, minification, container builds, or heavy bundling during routine code iterations.

### 6. No Unsolicited Media / Screenshots
- Do not take or inspect screenshots unless explicitly requested by the user or when visually debugging layout/rendering.

### 7. Concise, Direct Responses
- Keep explanations terse and focused on the solution.
- Use brief bullet points; omit conversational preamble and redundant code walk-throughs.

# Gas City Build Manual (Practical, Production-Oriented)

## 1. Core Mental Model

```
Gas City (gc) = workspace / supervisor
Beads (bd)    = task tracking
Agent         = worker (Claude Code, Codex, etc.)
Git           = source of truth (code)
```

Workflow:

```
bd create → agent implements → git commit → bd close
```

---

## 2. Install & Verify

```bash
brew install gascity

gc version
bd version
```

---

## 3. Create a City

```bash
gc init ~/my-city
```

Choose:

- minimal → simple coding setup (recommended first)
- gastown → full multi-agent system

Start city:

```bash
cd ~/my-city
gc start
```

Check:

```bash
gc cities
gc doctor
```

---

## 4. Create a Rig (Project)

```bash
mkdir hello-world
cd hello-world
git init

gc rig add .
```

This creates:

```
.git       → code repo
.beads     → task database
```

---

## 5. Initialize Beads (Important)

```bash
bd init --prefix hw
```

Keep it simple:

- role → do NOT change
- no contributor workflow

Verify:

```bash
bd config get issue_prefix
```

Expected:

```
hw
```

---

## 6. Create a Task

```bash
bd create "Create hello world script"
bd list
```

Example output:

```
hw-abc  Create hello world script
```

---

## 7. Implement Task (Manual)

```bash
echo 'print("hello world")' > hello.py
python3 hello.py
```

---

## 8. Commit Work

```bash
git add hello.py
git commit -m "feat: add hello world"
```

---

## 9. Close Task

```bash
bd close hw-abc
```

If ID fails:

```bash
bd update hw-abc --status closed
```

---

## 10. Using Claude Code (Agent Mode)

Start inside repo:

```bash
cd ~/my-city/hello-world
claude
```

Prompt:

```
Use Beads tasks as source.
Run: bd list
Pick open task.
Implement in repo.
Run program.
Show diff.
Do not commit.
```

Loop:

```
bd → Claude → review → git → bd close
```

---

## 11. Common Errors & Fixes

### issue\_prefix missing

```
bd init --prefix hw
```

### store is closed

```
gc stop
gc start
```

### no issues found

```
You reset .beads → create new task
```

### auto-export warning

Ignore or:

```bash
git add .beads
```

---

## 12. DeepSeek / Ollama Integration (Advanced)

Gas City supports custom agents.

Architecture:

```
gc → custom agent → local script → model (Ollama/DeepSeek)
```

Example:

```bash
gc init
→ choose "custom command"
→ point to: python3 ollama_worker.py
```

Worker must:

- read bd tasks
- read repo files
- call model
- write code
- run tests

---

## 13. When to Use gc

Use gc when:

- multi-task workflow
- multiple agents
- structured execution

Skip gc when:

- single script
- quick experiment

---

## 14. Daily Workflow

Start:

```bash
gc start
cd project
bd list
```

Work:

```bash
claude
→ implement
→ review
→ commit
```

Finish:

```bash
bd close <id>
```

End day:

```bash
gc stop
```

---

## 15. Key Insight

```
Gas City does NOT write code.
It organizes how code is written.
```

Agents write code. Beads tracks tasks. Git stores truth.

---

## 16. Minimal Professional Loop

```
1. bd create
2. claude implements
3. review diff
4. git commit
5. bd close
```

Repeat.


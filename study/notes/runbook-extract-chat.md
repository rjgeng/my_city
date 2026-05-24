# Runbook — extracting a Claude Code chat session to markdown

**Tool:** `study/scripts/extract_chat.py`
**When to use:** archiving a session, sharing with collaborators, feeding past conversations into wiki ingestion, post-hoc review.

---

## 1. Where session logs live

Claude Code writes one `.jsonl` file per session under:

```
~/.claude/projects/<encoded-project-path>/<session-uuid>.jsonl
```

For `my-city` the encoded path is `-Users-rfvitis-my-city` (slashes → dashes, leading `-`).

**Find your current session** (newest is the active one):

```bash
ls -t ~/.claude/projects/-Users-rfvitis-my-city/*.jsonl | head -1
```

The UUID also shows up in any tool-result paths during a session (e.g. `~/.claude/projects/.../<uuid>/tool-results/`).

---

## 2. What's in the .jsonl

Each LINE is one JSON record. Record types you'll see:

| Type | Keep? |
|---|---|
| `user` | yes (your typed messages + tool-result echoes) |
| `assistant` | yes (replies, thinking blocks, tool calls) |
| `system` | metadata, skip |
| `permission-mode`, `attachment`, `file-history-snapshot`, `ai-title`, `last-prompt` | metadata, skip |

**Content shape gotcha:**

- `user.message.content` is a STRING when you typed, or an ARRAY of blocks when it's a tool-result echo.
- `assistant.message.content` is always an ARRAY of blocks. Block types: `text` (visible reply), `thinking` (private reasoning), `tool_use` (function call).

---

## 3. Default extraction (the common case)

```bash
SESSION=~/.claude/projects/-Users-rfvitis-my-city/<uuid>.jsonl
python3 study/scripts/extract_chat.py "$SESSION" /tmp/chat.md
```

Defaults:
- Thinking blocks: **omitted** (private reasoning, often noisy)
- Tool result content: **omitted**, just a marker `*[tool result omitted]*`
- Tool calls: **annotated** as `*[tool call: <name>]*`

Output format: markdown, one section per message, separated by `---`, headed with role + timestamp.

---

## 4. Recipes

```bash
# WITH Claude's private reasoning (for review/learning)
python3 study/scripts/extract_chat.py "$SESSION" /tmp/chat-thinking.md --include-thinking

# WITH full tool-result echoes (verbose; for forensic review)
python3 study/scripts/extract_chat.py "$SESSION" /tmp/chat-full.md --include-tool-results

# BOTH (everything)
python3 study/scripts/extract_chat.py "$SESSION" /tmp/chat-everything.md \
    --include-thinking --include-tool-results

# Batch-extract every session in this project (one .md per session)
mkdir -p /tmp/all-chats
for j in ~/.claude/projects/-Users-rfvitis-my-city/*.jsonl; do
  python3 study/scripts/extract_chat.py "$j" "/tmp/all-chats/$(basename "$j" .jsonl).md"
done
```

---

## 5. Verify yourself before trusting the output

```bash
SESSION=~/.claude/projects/-Users-rfvitis-my-city/<uuid>.jsonl

# Confirm record types in the file
jq -r '.type' "$SESSION" | sort | uniq -c

# Count user/assistant records
jq -c 'select(.type == "user" or .type == "assistant")' "$SESSION" | wc -l

# Peek at any single record (replace 5 with the line number you want)
sed -n '5p' "$SESSION" | jq .

# After extraction, confirm section counts
grep -c '^## User' /tmp/chat.md
grep -c '^## Assistant' /tmp/chat.md
```

The extraction script also prints `user messages: N`, `assistant messages: M` on exit — compare with the `jq` counts.

---

## 6. Design choices in the script

- **Pure stdlib** (`json`, `pathlib`, `sys`) — no `pip install` needed; runs on any Python 3.
- **Stream-friendly** — reads the file line by line; works on multi-MB sessions without loading the whole file into memory.
- **Lossy by design** — defaults skip thinking + tool results because the use case is "readable transcript," not "forensic dump." Use the flags if you need the noise.
- **Markdown-first output** — easy to grep, easy to skim, plays well with any markdown viewer or wiki ingester.

---

## 7. When to commit / where to store output

- The script (`study/scripts/extract_chat.py`) is a reusable artifact — committed.
- Extracted transcripts (`.md` outputs) generally go to `/tmp/` for one-off use. Move to `study/notes/chatlogs/<date>.md` only if the conversation has lasting reference value (e.g., a foundational design discussion, an incident postmortem).

---

## 8. Soak / supervisor safety

This entire workflow is read-only against `~/.claude/projects/` and write-only to `/tmp/` (or wherever you point it). It does NOT touch `.gc/`, `.beads/`, or invoke `gc`/`bd`. Safe to run during any soak / supervisor-age experiment.

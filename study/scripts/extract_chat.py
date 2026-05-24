#!/usr/bin/env python3
"""
Extract a Claude Code session's chat log from its .jsonl file into a
clean markdown transcript.

WHERE SESSION FILES LIVE
    Claude Code stores each session as one .jsonl file under:
      ~/.claude/projects/<encoded-project-path>/<session-uuid>.jsonl

    For this project (my-city) the encoded path is `-Users-rfvitis-my-city`
    (slashes become dashes, prefixed with `-`).

    Each LINE in the .jsonl is one JSON record. Many record types appear
    (`permission-mode`, `system`, `user`, `assistant`, `attachment`,
    `file-history-snapshot`, `ai-title`, `last-prompt`). We care about
    just `user` and `assistant`.

CONTENT SHAPES (the part that bites you if you skip inspection)
    user.message.content:
        - a STRING when you typed a plain message
        - an ARRAY of blocks when the record is a tool-result echo
          (each block has `type: "tool_result"` etc.) — usually noise.

    assistant.message.content:
        - always an ARRAY of blocks. Block types we see:
            text       — the visible reply (KEEP)
            thinking   — Claude's private reasoning (SKIP by default)
            tool_use   — a tool/function call (annotate with the name)

USAGE
    python3 extract_chat.py <session.jsonl> [output.md]
    python3 extract_chat.py <session.jsonl> [output.md] --include-thinking
    python3 extract_chat.py <session.jsonl> [output.md] --include-tool-results

DEFAULTS
    - Output path: <session-uuid>.md in the current directory.
    - Thinking blocks: omitted.
    - Tool results (verbose user-side echoes): omitted (just a marker shown).
"""

import json
import sys
from pathlib import Path


def extract_user_text(content, include_tool_results=False):
    """User content is either a string or an array of blocks."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if btype == "text":
                parts.append(block.get("text", ""))
            elif btype == "tool_result":
                if include_tool_results:
                    result = block.get("content", "")
                    if isinstance(result, list):
                        # tool_result content can itself be a list of {type, text} blocks
                        result = "\n".join(
                            b.get("text", "") for b in result
                            if isinstance(b, dict) and b.get("type") == "text"
                        )
                    parts.append(f"*[tool result]*\n```\n{result}\n```")
                else:
                    parts.append("*[tool result omitted]*")
        return "\n\n".join(p for p in parts if p)
    return ""


def extract_assistant_text(content, include_thinking=False):
    """Assistant content is always an array of blocks."""
    if not isinstance(content, list):
        return ""
    parts = []
    for block in content:
        if not isinstance(block, dict):
            continue
        btype = block.get("type")
        if btype == "text":
            parts.append(block.get("text", ""))
        elif btype == "thinking" and include_thinking:
            parts.append(f"*[thinking]*\n> {block.get('thinking', '').replace(chr(10), chr(10) + '> ')}")
        elif btype == "tool_use":
            name = block.get("name", "?")
            parts.append(f"*[tool call: `{name}`]*")
    return "\n\n".join(p for p in parts if p)


def main():
    args = sys.argv[1:]
    include_thinking = "--include-thinking" in args
    include_tool_results = "--include-tool-results" in args
    positional = [a for a in args if not a.startswith("--")]

    if not positional:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    src = Path(positional[0]).expanduser()
    if not src.exists():
        print(f"Not found: {src}", file=sys.stderr)
        sys.exit(1)

    session_id = src.stem
    dst = Path(positional[1]).expanduser() if len(positional) >= 2 else Path(f"{session_id}.md")

    out = [f"# Claude Code session: {session_id}",
           f"_Source: {src}_",
           ""]

    user_count = assistant_count = skipped = 0

    with src.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                skipped += 1
                continue

            rtype = rec.get("type")
            if rtype not in ("user", "assistant"):
                continue

            ts = rec.get("timestamp", "")
            msg = rec.get("message", {})
            content = msg.get("content", "")

            if rtype == "user":
                text = extract_user_text(content, include_tool_results)
                if not text or not text.strip():
                    continue
                out.append(f"\n---\n\n## User — {ts}\n\n{text}\n")
                user_count += 1
            else:
                text = extract_assistant_text(content, include_thinking)
                if not text or not text.strip():
                    continue
                out.append(f"\n---\n\n## Assistant — {ts}\n\n{text}\n")
                assistant_count += 1

    dst.write_text("\n".join(out))
    print(f"Wrote {dst}")
    print(f"  user messages:      {user_count}")
    print(f"  assistant messages: {assistant_count}")
    if skipped:
        print(f"  skipped malformed:  {skipped}")


if __name__ == "__main__":
    main()

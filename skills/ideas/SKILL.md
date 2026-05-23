# ideas

Captures a single idea so it is not lost and does not interrupt what you are currently doing. Quick, low-friction, no triage.

## When to use

Any time an idea arrives and you do not want to lose it but also do not want to act on it right now. Invoke, capture, return to your current work.

## IP boundary

If you are running this skill from a work repo, stop and switch to your personal project repo first.

## Prompt

Provide:

1. **Title** — a short phrase that identifies the idea (required)
2. **Context** — one or two sentences of optional background, motivation, or detail (optional)

## Output

Appends to `ideas.md` relative to the current working directory in the following format:

```
## {title}
*{YYYY-MM-DD}*

{context if provided}

---
```

File location: written relative to the current working directory. Add ideas.md to your .gitignore if you do not want it committed.

This skill does not create issues, does not route to any planning agent, and does not perform triage. The idea lives in `ideas.md` until you decide what to do with it.

# project-health

A structured self-assessment of your project's current state. Surfaces at-risk signals early and prompts a scope-brake check inline when the project needs it.

## When to use

Run when you feel uncertain about the project's direction, when you notice you have not opened the repo in a while, or as a regular (monthly or quarterly) check-in.

## Prompt

Answer the following four questions about your project:

1. **Open issue count** — How many open issues or tracked tasks does the project currently have?
2. **Last commit date** — When did you last commit to this project? (approximate is fine)
3. **Last external interaction** — When did you last hear from, respond to, or interact with an external user of this project? (If there are no external users, note that.)
4. **Self-reported energy** — On a scale of 1 to 5, how energised do you feel about this project right now?

## Health summary

After answering, produce a brief health summary: one short paragraph covering each of the four signals and an overall sense of where the project stands.

## At-risk detection

The project is considered **at-risk** when any two of the following apply:

- Open issue count is greater than 30
- Last commit was more than 14 days ago
- Self-reported energy is 1 or 2

If at-risk, output the following three questions immediately after the health summary:

1. What is the current issue scope?
2. What does this new idea add?
3. Can it wait?

These questions are here to help you pause and protect your current focus before deciding what to do next. They are provided inline — you do not need to invoke any other skill.

## Output

Inline conversation text only. No file is written. No subagent is spawned.

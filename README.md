# respit

Personal Copilot CLI plugin for work-life harmony and personal productivity.

![Version](https://img.shields.io/badge/version-1.0.3-blue)

## Requirements

- GitHub Copilot subscription
- [GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/copilot-cli/using-github-copilot-in-the-command-line) installed and authenticated

## Install

**Via Foculoom marketplace (recommended):**
```
copilot plugin marketplace add foculoom/plugins
copilot plugin install respit
```

**Direct install:**
```
copilot plugin install foculoom/respit
```

## Skills

| Skill | Description |
|-------|-------------|
| `energy-check` | A brief self-assessment to surface how you are feeling about your work right now. |
| `ideas` | Captures a single idea so it is not lost and does not interrupt what you are currently doing. |
| `personal-retro` | A lightweight retrospective for solo project work. Designed to surface what is worth protecting and what is quietly draining you. |
| `project-health` | A structured self-assessment of your project's current state. Surfaces at-risk signals early and prompts a scope-brake check inline when the project needs it. |
| `scope-brake` | A three-question pause that keeps creative momentum from accidentally turning into scope sprawl. |

## Usage

Invoke any skill by name in a Copilot CLI session:

```
/energy-check
/scope-brake
/personal-retro
/project-health
/ideas
```

## License

MIT — Copyright (c) 2026 Foculoom LLC

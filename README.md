# adversarial-review

A self-contained Codex skill for running adversarial reviews of code, plans, diffs, pull requests, implementations, and agent output.

The skill helps a lead agent dispatch independent reviewers through the best available route: a different tool such as Codex calling Claude Code, the same tool's subagent system, a fresh same-tool CLI session, or a clearly labeled single-agent fallback.

## Contents

- `skills/adversarial-review/SKILL.md`: the review workflow, reviewer lenses, prompt template, and verdict format.
- `skills/adversarial-review/agents/openai.yaml`: Codex/OpenAI UI metadata.

## Install

Install or copy the `skills/adversarial-review` folder into the skill directory used by your agent host.

For Codex workspaces, keep the skill project-local when possible:

```sh
mkdir -p .codex/skills
cp -R skills/adversarial-review .codex/skills/
```

For other hosts, use that host's normal project-local skill/plugin mechanism and point it at `skills/adversarial-review/SKILL.md`.

## Use

Ask your agent to use the skill:

```text
Use $adversarial-review to review this diff with a Codex subagent and Claude Code.
```

The skill will:

1. State the intent and freeze the review scope.
2. Probe available reviewer routes.
3. Dispatch one reviewer per lens when appropriate.
4. Synthesize findings into `PASS`, `CONTESTED`, or `REJECT`.
5. Record reviewer setup, configuration posture, permission posture, missing evidence, and lead judgment.

## Reviewer Routes

| Route | Example |
| --- | --- |
| Cross-tool reviewer | Codex calls Claude Code, or Claude Code calls Codex |
| Same-tool subagent | Codex starts isolated Codex subagents |
| Same-tool CLI session | Codex starts a fresh `codex exec` reviewer |
| Single-agent fallback | The lead runs each lens itself and labels the lack of independence |

Reviewer tools should load normal user and project configuration by default. That keeps local rules, team policies, and project conventions active during review. Reviewers should still be read-only by default; if a route cannot be constrained, pass a static review packet instead of workspace access.

## Validate

This repository includes a lightweight validation script:

```sh
./runtest.sh
```

Before publishing, also verify from a fresh clone that the tracked repository contains `skills/adversarial-review/SKILL.md` and `skills/adversarial-review/agents/openai.yaml`.

## License

MIT. See `LICENSE`.

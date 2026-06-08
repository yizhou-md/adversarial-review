# adversarial-review

A self-contained Codex skill for running adversarial reviews of code, plans, diffs, pull requests, implementations, and agent output.

The skill helps a lead agent dispatch independent reviewers through a user-specified route: a different tool such as Codex calling Claude Code, the same tool's subagent system, a fresh same-tool CLI session, or a clearly labeled single-agent fallback. If the user has not specified a route, the agent should ask before dispatching reviewers.

This skill references the public [`pedronauck/skills` `adversarial-review` skill](https://claudemarketplaces.com/skills/pedronauck/skills/adversarial-review). It keeps the adversarial reviewer lens pattern, but adapts the route policy for Codex use: the user chooses the review route, including subagents when requested.

## Contents

- `skills/adversarial-review/SKILL.md`: the review workflow, reviewer lenses, prompt template, and verdict format.
- `skills/adversarial-review/agents/openai.yaml`: Codex/OpenAI UI metadata.

## Install

Install with the Agent Skills CLI:

```sh
pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review
```

You can also use the equivalent `npx skills add ...` form if that is how you normally run the skills installer.

## Use

Ask your agent to use the skill:

```text
Use $adversarial-review to review this diff with a Codex subagent and Claude Code.
```

The skill will:

1. State the intent and freeze the review scope.
2. Confirm the user-specified reviewer route, asking for one if it is missing.
3. Dispatch one reviewer per lens when appropriate. The lenses are `Skeptic`, `Architect`, and `Minimalist`.
4. Synthesize findings into `PASS`, `CONTESTED`, or `REJECT`.
5. Record reviewer setup, configuration posture, permission posture, missing evidence, and lead judgment.

## Reviewer Lenses

- `Skeptic`: checks whether the work is correct, complete, and verified.
- `Architect`: checks whether the structure, boundaries, and contracts fit the stated goal.
- `Minimalist`: checks whether the work can be simpler, smaller, or less speculative.

## Reviewer Routes

The user should name the route to use. The skill does not choose a route just because it is available.

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

## License

MIT. See `LICENSE`.

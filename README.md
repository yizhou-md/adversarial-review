# adversarial-review

Ship with fewer blind spots.

`adversarial-review` is a self-contained Codex skill for challenging code, plans, diffs, pull requests, implementations, and agent output before you trust them. It is built for the moment when "looks good" is not enough and you want a reviewer to ask: what would make this wrong?

At its core, the skill treats adversarial review as falsification: frame a claim under test, send reviewers or review passes to look for concrete counterexamples, then decide whether those counterexamples change the verdict.

Unlike a casual self-check, this skill keeps independence explicit. Reviewers run through a user-specified route: another tool such as Codex calling Claude Code, a same-tool subagent, a fresh same-tool CLI session, or a clearly labeled single-agent manual route. If the user has not named the route, the skill asks before dispatching anyone.

The skill references the public [`pedronauck/skills` `adversarial-review` skill](https://claudemarketplaces.com/skills/pedronauck/skills/adversarial-review). It keeps the useful reviewer-lens pattern, then adapts the route policy for Codex: the user chooses the route, and the skill records independence posture without ranking routes for them.

## What You Get

- A clear intent statement and a falsifiable claim under test.
- A frozen review scope, so reviewers critique the same artifact.
- Findings from one or more lenses: `Skeptic`, `Architect`, and `Minimalist`.
- A synthesized verdict: `PASS`, `CONTESTED`, or `REJECT`.
- Reviewer setup notes, permission posture, missing evidence, and lead judgment for every accepted finding.

## Contents

- `skills/adversarial-review/SKILL.md`: the review workflow, reviewer lenses, prompt template, synthesis rules, and verdict format.
- `skills/adversarial-review/agents/openai.yaml`: Codex/OpenAI UI metadata.

## Install

Install with the Agent Skills CLI:

```sh
pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review
```

## Use

Tell your agent what to review and which route to use:

```text
Use $adversarial-review to review this diff with a Codex subagent and Claude Code.
```

The skill will:

1. Turn the intent into a falsifiable claim under test, including success criteria and failure conditions.
2. Freeze the review scope: diff, PR, plan, files, or another concrete artifact.
3. Confirm the user-specified reviewer route, asking for one if it is missing.
4. Dispatch reviewers with the selected lenses when the route supports it.
5. Deduplicate findings and judge whether each one changes the final verdict.
6. Return the verdict with concrete evidence, failure scenarios, and recommended next actions.

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
| Single-agent manual review | The lead runs each lens itself and labels that no independent reviewer was used |

Reviewer tools should load normal user and project configuration by default. That keeps local rules, team policies, and project conventions active during review. Reviewers should still be read-only by default; if a route cannot be constrained, pass a static review packet instead of workspace access.

Independence and permission posture are separate. A cross-tool reviewer can be more independent while still lacking a filesystem read-only sandbox; tool restrictions are not filesystem sandboxes, so the skill records the actual posture instead of upgrading it in the verdict. For Claude Code, a static review packet with disabled tools is recorded as `static packet / tools disabled`; live workspace access through plan mode or tool controls is recorded as `tool-restricted plan mode` or the exact posture used.

## When Not To Use

- Do not use this skill for quick self-checks where the user has not asked for a specific adversarial route.
- Do not use it when the user has not specified a reviewer route; ask for the route first.
- Do not use it as an editing or remediation workflow unless the user explicitly asks for fixes after the review.
- Do not use it for style-only proofreading, formatting, or lint cleanup where no adversarial risk review is needed.

## Validate

This repository includes a lightweight package and workflow validation script. It checks the skill package structure, route policy, documentation, and core workflow invariants; it does not dispatch real reviewer tools.

```sh
./runtest.sh
```

## License

MIT. See `LICENSE`.

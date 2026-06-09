# adversarial-review

[English](README.md) | [简体中文](README-zh.md)

> Ship with fewer blind spots.

`adversarial-review` is a Codex skill. It challenges code, plans, diffs, pull requests, implementations, and agent output before you trust them. It is built for the moment when "looks good" is not enough and you want a reviewer to ask: what evidence would show this was not actually done well?

## What Problem It Solves

Casual self-checks often start from the hidden assumption that "I am probably right." Adversarial review flips that default: first state the result as a falsifiable claim under test, then deliberately look for counterexamples that would disprove it.

This is not about being harsh, and it is not another lint pass. It looks for concrete scenarios that would change the verdict: edge inputs, missing verification, incorrect permission assumptions, unnecessary complexity, or reviewers accidentally looking at different artifacts.

## How It Works

`adversarial-review` breaks falsification into three steps:

1. **Frame the hypothesis**: turn "I think this is fine" into a falsifiable claim under test, with success criteria and failure conditions.
2. **Look for independent counterexamples**: freeze the review scope, then send reviewers or review passes to challenge it through assigned lenses.
3. **Decide the verdict**: judge whether the findings change the final verdict: `PASS`, `CONTESTED`, or `REJECT`.

Unlike a casual self-check, this skill keeps independence explicit without making users memorize route names first. Reviewers run through a route the user names or through the default route policy: another tool such as Codex calling Claude Code, a same-tool subagent, a fresh same-tool CLI session, or a clearly labeled single-agent manual route.

The skill references the public [`pedronauck/skills` `adversarial-review` skill](https://claudemarketplaces.com/skills/pedronauck/skills/adversarial-review). It keeps the useful reviewer-lens pattern, then adapts the route policy for Codex: the user may choose the route, omitted routes resolve by context, and the skill records the real independence state without ranking routes by availability.

## What You Get

- A clear intent statement and a falsifiable claim under test.
- A frozen review scope, so reviewers critique the same artifact.
- Findings from one or more lenses: `Skeptic`, `Architect`, and `Minimalist`.
- A synthesized verdict: `PASS`, `CONTESTED`, or `REJECT`.
- Traceable review notes: what may be wrong, why it matters, whether it affects the verdict, and what to do next.

## Contents

- `skills/adversarial-review/SKILL.md`: the review workflow, reviewer lenses, prompt template, synthesis rules, and verdict format.
- `skills/adversarial-review/agents/openai.yaml`: Codex/OpenAI UI metadata.

## Install

Install with the Agent Skills CLI:

```sh
pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review
```

## Use

Tell your agent what to review. You may name a reviewer route, but you do not have to know the route vocabulary before using the skill:

```text
Use $adversarial-review to review this diff with a Codex subagent and Claude Code.
```

The skill will:

1. Turn the intent into a falsifiable claim under test, including success criteria and failure conditions.
2. Freeze the review scope: diff, PR, plan, files, or another concrete artifact.
3. Resolve the reviewer route: use the route you named, ask with options in interactive chat, or default to same-tool subagent in non-interactive automation.
4. Dispatch reviewers with the selected lenses when the route supports it.
5. Deduplicate findings and judge whether each one changes the final verdict.
6. Return the verdict with concrete evidence, failure scenarios, and recommended next actions.

## Reviewer Lenses

| Lens | Focus |
| --- | --- |
| `Skeptic` | Checks whether the work is correct, complete, and verified. |
| `Architect` | Checks whether the structure, boundaries, and contracts fit the stated goal. |
| `Minimalist` | Checks whether the work can be simpler, smaller, or less speculative. |

## Reviewer Routes (Who Reviews)

You can name the route to use, or let the missing-route policy apply. Here, "route" means the reviewer's execution mode, not a file path. The skill does not choose a route just because it is available.

| Route | Example |
| --- | --- |
| Cross-tool reviewer | Codex calls Claude Code, or Claude Code calls Codex |
| Same-tool subagent | Codex starts isolated Codex subagents |
| Same-tool CLI session | Codex starts a fresh `codex exec` reviewer |
| Single-agent manual review | The lead runs each lens itself and labels that no independent reviewer was used |

If no route is named in an interactive chat, the skill shows the route options, recommends same-tool subagent, and asks before dispatching reviewers. In non-interactive automation, the default route is same-tool subagent. If the requested or default route is unavailable, the skill reports the blocker instead of silently switching to another route.

Reviewer tools should load normal user and project configuration by default. That keeps local rules, team policies, and project conventions active during review. Reviewers should still be read-only by default; if a route cannot be constrained reliably, pass a static review packet instead of workspace access.

Independence and permission state are separate. A cross-tool reviewer can be more independent while still lacking a filesystem read-only sandbox; tool restrictions are not filesystem sandboxes, so the skill records the actual permission state instead of upgrading it in the verdict. For Claude Code, a static review packet with disabled tools is recorded as `static packet / tools disabled`; live workspace access through plan mode or tool controls is recorded as `tool-restricted plan mode` or the exact permission state used.

## When Not To Use

- Do not use this skill for quick self-checks where the user has not asked for adversarial review.
- Do not treat the default route as permission to install missing tools or silently switch routes.
- Do not use it as an editing or remediation workflow unless the user explicitly asks for fixes after the review.
- Do not use it for style-only proofreading, formatting, or lint cleanup where no adversarial risk review is needed.

## Validate

This repository includes a lightweight package and workflow validation script. It checks the skill package structure, route policy, documentation, and core workflow invariants; it does not dispatch real reviewer tools.

```sh
./runtest.sh
```

## License

MIT. See `LICENSE`.

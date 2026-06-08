---
name: adversarial-review
description: Use when reviewing code, plans, diffs, pull requests, implementations, or agent output where an adversarial reviewer or review pass should challenge correctness, architecture, scope, assumptions, verification, or unnecessary complexity.
---

# Adversarial Review

Use an explicit reviewer route to attack whether the work achieves the stated intent. Adversarial review is a falsification exercise, not a second implementation pass: the lead frames a claim under test, reviewers or review passes try to disprove the strongest version of that claim with concrete counterexamples, and synthesis decides whether those counterexamples change the verdict. The deliverable is a verdict, not edits. Do not modify files during this skill unless the user explicitly asks for remediation after the review.

## Core Rules

- The user must explicitly specify the reviewer route: same tool, different tool, specific CLI, subagent, or single-agent manual review.
- If the user has not specified a reviewer route, stop and ask which route to use before dispatching reviewers.
- Stronger independence is desirable, but it is not a reason to override or infer the route. A well-isolated same-tool subagent is valid when the user specifies it.
- Frame a falsifiable `Claim under test` before dispatch. Include success criteria, failure conditions, and non-goals when they are known.
- Steelman the intent before attacking it. Review the strongest defensible version of the work, not a weak caricature.
- Keep reviewer context minimal: intent, scope, evidence, assigned lens, and the review contract. Do not pass the lead agent's draft conclusions.
- Reviewers must be read-only by default. If a reviewer cannot be constrained to read-only, send a static review packet instead of workspace access.
- Reviewer tools should load their normal user and project configuration by default so local rules, policies, and team conventions are respected.
- Missing reviewer output is evidence. Report it; do not silently synthesize around it.
- Adversarial does not mean hostile. Findings need concrete failure scenarios, file or artifact references, and actionable recommendations.
- Every accepted finding must state `Verdict impact`: why it changes, blocks, or does not change `PASS`, `CONTESTED`, or `REJECT`.
- Do not install a missing reviewer tool just to run this skill unless the user explicitly approves installation. If the requested route cannot run, report the failed route and ask whether to use another route.

## Workflow

1. State the intent in one or two sentences, then frame the `Claim under test`: what must be true for this work to count as successful, plus success criteria and failure conditions.
2. Freeze the review scope: current diff, staged diff, commit range, PR, plan, files, or user-provided artifact.
3. Confirm the user-specified reviewer route. If it is missing or ambiguous, ask the user which route to use and stop until they answer.
4. Collect evidence. For git work, prefer `git status --short`, `git diff --stat`, and the relevant `git diff` or PR diff. If there is no git repo, list the files or artifact sections being reviewed.
5. Choose reviewers from the risk table and dispatch them with the lens prompts below through the specified route. Run reviewers in parallel when the tool permits it.
6. Verify each reviewer produced output.
7. Deduplicate findings, apply lead judgment, record `Verdict impact` for accepted findings, and return the verdict format.

Risk overrides size. Changed-line count is only the starting signal; upgrade the reviewer set when the change touches security, privacy, data loss, migrations, concurrency, permissions, dependency changes, or external publishing.

| Risk profile | Examples | Default reviewers |
| --- | --- | --- |
| Low | Under 50 changed lines, 1-2 small files, docs-only, tests-only, or isolated implementation with no contract change | Skeptic |
| Moderate | 50-200 changed lines, 3-5 files, API or prompt contract changes, non-trivial refactors, or behavior that needs architectural judgment | Skeptic, Architect |
| High | Over 200 changed lines, more than 5 files, cross-module changes, privileged tool access, persistence, destructive operations, or any high-impact failure mode | Skeptic, Architect, Minimalist |

## Reviewer Route Selection

Use only the route explicitly specified by the user. Do not infer a route from availability, preference, or perceived independence.

| Route | Use when | Independence |
| --- | --- | --- |
| Cross-tool reviewer | The user asks for another tool, such as Codex calling Claude Code or Claude calling Codex | Highest |
| Same-tool subagent | The user asks to use same-tool subagents or multi-agent delegation | Good if isolated |
| Same-tool CLI session | The user asks for a fresh non-interactive session from the same agent CLI | Moderate |
| Single-agent manual review | The user asks the lead to run the lenses itself | None; label clearly |

If the route is missing, ask the user to choose one of the routes above. If the requested route is unavailable, report the exact blocker and ask whether to switch routes. Do not silently substitute a different route.

### Route Discovery

Before dispatch, probe only the user-specified route and record the result in `Reviewer Setup`.

- Cross-tool CLI: check whether the requested CLI is available, such as `command -v codex` or `command -v claude`.
- Same-tool subagent: confirm the current host exposes a subagent or delegation primitive and note the spawned agent/session id.
- Same-tool CLI: check whether the current tool can start a fresh non-interactive reviewer session.
- Single-agent manual review: use when the user specified this route, and record that no independent reviewer was used.

### CLI Adapter Examples

CLI flags change. Check the active adapter help before first use, such as `codex exec --help` and `claude --help`.
Use normal local configuration by default. Prefer ephemeral or no-session-persistence modes when available so reviewer conversations are not retained unnecessarily, but do not suppress user or project rules just to make the review more "portable". Record the configuration posture in `Reviewer Setup`.

Permission posture is separate from reviewer independence. Codex `--sandbox read-only` is the adapter's filesystem read-only sandbox posture when the active host enforces that mode. Claude Code tool controls such as `--tools ""`, `--allowedTools`, `--disallowedTools`, or `--permission-mode plan` are tool restrictions, and tool restrictions are not filesystem sandboxes. A Claude Code static-packet reviewer with disabled tools should be recorded as `static packet / tools disabled`; a Claude Code reviewer with live workspace access through plan mode or tool controls should be recorded as `tool-restricted plan mode` or the exact posture used, and must not be reported as filesystem read-only unless the host provides a named filesystem sandbox.

Codex reviewer example:

```sh
set -euo pipefail

command -v codex >/dev/null 2>&1 || {
  echo "codex CLI not found" >&2
  exit 1
}

REVIEW_WORK_DIR="$(mktemp -d -t adversarial-review.XXXXXX)"
trap 'rm -rf "$REVIEW_WORK_DIR"' EXIT

OUTPUT_DIR="${OUTPUT_DIR:-$PWD/review-output}"
mkdir -p "$OUTPUT_DIR"

PROMPT_FILE="$REVIEW_WORK_DIR/skeptic-prompt.md"
OUTPUT_FILE="$OUTPUT_DIR/skeptic.md"
# Write the reviewer prompt packet to "$PROMPT_FILE" before running the CLI.
test -s "$PROMPT_FILE" || {
  echo "missing reviewer prompt: $PROMPT_FILE" >&2
  exit 1
}

codex exec \
  --skip-git-repo-check \
  --ephemeral \
  --sandbox read-only \
  -C "$PWD" \
  -o "$OUTPUT_FILE" \
  - < "$PROMPT_FILE"

test -s "$OUTPUT_FILE" || {
  echo "reviewer produced no output: $OUTPUT_FILE" >&2
  exit 1
}
```

Claude static-packet reviewer example:

```sh
set -euo pipefail

command -v claude >/dev/null 2>&1 || {
  echo "claude CLI not found" >&2
  exit 1
}

REVIEW_WORK_DIR="$(mktemp -d -t adversarial-review.XXXXXX)"
trap 'rm -rf "$REVIEW_WORK_DIR"' EXIT

OUTPUT_DIR="${OUTPUT_DIR:-$PWD/review-output}"
mkdir -p "$OUTPUT_DIR"

PROMPT_FILE="$REVIEW_WORK_DIR/skeptic-prompt.md"
OUTPUT_FILE="$OUTPUT_DIR/skeptic.md"
# Write the reviewer prompt packet to "$PROMPT_FILE" before running the CLI.
test -s "$PROMPT_FILE" || {
  echo "missing reviewer prompt: $PROMPT_FILE" >&2
  exit 1
}

claude \
  --print \
  --no-session-persistence \
  --output-format text \
  --permission-mode plan \
  --tools "" \
  < "$PROMPT_FILE" \
  > "$OUTPUT_FILE"

test -s "$OUTPUT_FILE" || {
  echo "reviewer produced no output: $OUTPUT_FILE" >&2
  exit 1
}
```

When using this static-packet example, record the permission posture as `static packet / tools disabled`. The `--permission-mode plan` flag is an extra guard, but because the reviewer receives a static packet and `--tools ""` disables tools, this route must not be recorded as `tool-restricted plan mode` and must not be reported as filesystem read-only.

If a Claude reviewer must inspect the workspace directly instead of a static packet, probe the active `claude --help`, constrain it with planning or tool-deny controls when available, and record the exact permission posture. Tool-deny or plan-mode controls must not be reported as filesystem read-only.

Same-tool subagent adapter:

```text
Start one isolated subagent per lens. Give each subagent only the review packet,
its assigned lens, and the instruction to return findings without editing files.
Do not show one reviewer another reviewer's output until synthesis.
```

For each subagent, record:

- lens name
- agent or session id
- whether it received workspace access or a static packet
- read-only or no-edit constraint used
- output status: completed, missing, empty, or failed

## Lenses

### Skeptic

Challenge correctness, completeness, and verification.

Ask:

- What inputs, states, or sequences break this?
- What would make the claim false?
- What is the smallest counterexample that disproves the claim?
- What error paths are unhandled or silently swallowed?
- What race conditions, ordering dependencies, or state leaks exist?
- What assumptions are asserted but not proven?
- Where does verification fail to cover the behavior that matters?

### Architect

Challenge structural fitness.

Ask:

- Does the design serve the stated goal, or a goal the author assumed?
- Does the structure support the claim under test, or only a narrower happy path?
- Where do responsibilities leak across boundaries?
- Which coupling points will hurt when requirements shift?
- What implicit assumptions about scale, concurrency, persistence, or ownership will break first?
- Are APIs, schemas, contracts, or module boundaries coherent?

### Minimalist

Challenge necessity and complexity.

Ask:

- What can be deleted without losing the stated goal?
- Which parts are unnecessary for the claim under test?
- Where is the author solving a future problem without evidence?
- What abstractions exist for a single concrete use case?
- Where did configuration or flexibility appear without a second real consumer?
- Is there a simpler path with the same outcome and lower risk?

## Reviewer Prompt Template

Use this template for every reviewer. Replace bracketed fields before dispatch.

```text
You are an adversarial reviewer. Do not edit files.

Intent:
[state the author's intended outcome]

Claim under test:
[state the falsifiable claim being reviewed]

Success criteria:
[what must be true for the claim to hold]

Failure conditions:
[what would make the claim false]

Non-goals:
[what is outside the claim, if known]

Scope:
[diff, files, PR, plan, artifact, or exact sections under review]

Evidence:
[paste or summarize the review packet; include commands already run and their relevant output]

Your lens:
[Skeptic | Architect | Minimalist]

Lens instructions:
[paste the full lens definition from this skill]

Review contract:
- Steelman the intent before attacking it.
- Find real problems, not style preferences.
- Look for the smallest counterexample that would make the claim false.
- Cite concrete files, lines, commands, artifacts, or missing evidence when possible.
- Explain the failure scenario for each finding.
- Explain `Verdict impact`: whether and why the finding changes `PASS`, `CONTESTED`, or `REJECT`.
- Rate severity as high, medium, or low.
- Recommend a concrete action.
- If you find no issue, say so and name the evidence that made you confident.
- Return only your review in markdown.

Output format:
## [Lens] Review
1. **[severity] Finding title**
   - Evidence:
   - Failure scenario:
   - Verdict impact:
   - Recommendation:
```

## Synthesis Rules

- Read every reviewer output before deciding.
- Synthesize against the `Claim under test`, not general preferences or unasked-for goals.
- Mark missing or empty outputs in `Reviewer Setup`.
- Merge duplicate findings, preserving all lenses that raised them.
- Accept only findings that are grounded in evidence or a plausible failure path.
- Reject false positives explicitly. Adversarial reviewers are expected to overreach sometimes.
- If verification is missing, distinguish "known broken" from "not proven".
- For every accepted finding, state `Verdict impact`; if it does not affect the final verdict, explain why it remains residual risk instead of a blocker.

## Verdict Format

```markdown
## Intent
<what the work is trying to achieve>

## Claim Under Test
<falsifiable claim, success criteria, failure conditions, and known non-goals>

## Reviewer Setup
- Lead: <current agent/tool>
- Route: <cross-tool | same-tool subagent | same-tool CLI | single-agent manual review>
- Reviewers: <lens -> tool; session; config posture; permission posture; output status>
- Config posture: <normal local config loaded | custom config | unknown>
- Permission posture summary: <filesystem read-only sandbox | static packet / tools disabled | tool-restricted plan mode | mixed | unknown | other>
- Scope: <diff/files/PR/plan/artifact>
- Missing evidence: <none, or exact gaps>

## Verdict: PASS | CONTESTED | REJECT
<one-line summary>

## Findings
<numbered list ordered by severity, high to low>

For each finding:
- **[severity]** <description with concrete evidence>
- Raised by: <lens names>
- Failure scenario: <what could go wrong>
- Verdict impact: <why this changes or does not change the verdict>
- Recommendation: <specific next action>
- Lead judgment: <accept | reject> - <brief rationale>

## What Went Well
<1-3 grounded positives, or "No separate positives identified.">

## Residual Risk
<important uncertainty that remains after the review>
```

Verdict logic:

- Use `mixed` in `Permission posture summary` when reviewers used different permission postures, and keep each exact posture in the per-reviewer `Reviewers` entry.
- `PASS`: no accepted high-severity findings.
- `CONTESTED`: at least one high-severity claim is plausible but disputed, unverified, or blocked by missing evidence. Also use this when multiple accepted medium findings make the work risky to ship even without a single blocker.
- `REJECT`: at least one accepted high-severity finding blocks the stated intent.

## Unavailable Route Behavior

If the requested route cannot be spawned, report the blocker and ask whether the user wants to choose another route. Do not switch to single-agent manual review unless the user specifies that route. Keep the verdict useful, but be explicit when independence was not achieved.

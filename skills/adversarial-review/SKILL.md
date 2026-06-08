---
name: adversarial-review
description: Use when reviewing code, plans, diffs, pull requests, implementations, or agent output where an independent adversarial reviewer should challenge correctness, architecture, scope, assumptions, verification, or unnecessary complexity.
---

# Adversarial Review

Use independent reviewers to attack whether the work achieves the stated intent. The deliverable is a verdict, not edits. Do not modify files during this skill unless the user explicitly asks for remediation after the review.

## Core Rules

- The user must explicitly specify the reviewer route: same tool, different tool, specific CLI, subagent, or manual fallback.
- If the user has not specified a reviewer route, stop and ask which route to use before dispatching reviewers.
- Stronger independence is desirable, but it is not a reason to override or infer the route. A well-isolated same-tool subagent is valid when the user specifies it.
- Keep reviewer context minimal: intent, scope, evidence, assigned lens, and the review contract. Do not pass the lead agent's draft conclusions.
- Reviewers must be read-only by default. If a reviewer cannot be constrained to read-only, send a static review packet instead of workspace access.
- Reviewer tools should load their normal user and project configuration by default so local rules, policies, and team conventions are respected.
- Missing reviewer output is evidence. Report it; do not silently synthesize around it.
- Adversarial does not mean hostile. Findings need concrete failure scenarios, file or artifact references, and actionable recommendations.
- Do not install a missing reviewer tool just to run this skill unless the user explicitly approves installation. If the requested route cannot run, report the failed route and ask whether to use another route.

## Workflow

1. State the intent in one or two sentences.
2. Freeze the review scope: current diff, staged diff, commit range, PR, plan, files, or user-provided artifact.
3. Confirm the user-specified reviewer route. If it is missing or ambiguous, ask the user which route to use and stop until they answer.
4. Collect evidence. For git work, prefer `git status --short`, `git diff --stat`, and the relevant `git diff` or PR diff. If there is no git repo, list the files or artifact sections being reviewed.
5. Choose reviewers from the risk table and dispatch them with the lens prompts below through the specified route. Run reviewers in parallel when the tool permits it.
6. Verify each reviewer produced output.
7. Deduplicate findings, apply lead judgment, and return the verdict format.

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
| Single-agent fallback | The user asks for manual fallback, or approves it after a requested independent route fails | Lowest; label clearly |

If the route is missing, ask the user to choose one of the routes above. If the requested route is unavailable, report the exact blocker and ask whether to switch routes. Do not silently substitute a different route.

### Route Discovery

Before dispatch, probe only the user-specified route and record the result in `Reviewer Setup`.

- Cross-tool CLI: check whether the requested CLI is available, such as `command -v codex` or `command -v claude`.
- Same-tool subagent: confirm the current host exposes a subagent or delegation primitive and note the spawned agent/session id.
- Same-tool CLI: check whether the current tool can start a fresh non-interactive reviewer session.
- Fallback: only use `single-agent fallback` when the user requested it or approved it after a requested independent route failed.

### CLI Adapter Examples

CLI flags change. Check `--help` in the active environment before first use.
Use normal local configuration by default. Prefer ephemeral or no-session-persistence modes when available so reviewer conversations are not retained unnecessarily, but do not suppress user or project rules just to make the review more "portable". Record the configuration posture in `Reviewer Setup`.

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
  --tools "" \
  < "$PROMPT_FILE" \
  > "$OUTPUT_FILE"

test -s "$OUTPUT_FILE" || {
  echo "reviewer produced no output: $OUTPUT_FILE" >&2
  exit 1
}
```

If a Claude reviewer must inspect the workspace directly instead of a static packet, constrain it with that host's read-only, planning, or tool-deny mode and record the exact permission posture.

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
- What error paths are unhandled or silently swallowed?
- What race conditions, ordering dependencies, or state leaks exist?
- What assumptions are asserted but not proven?
- Where does verification fail to cover the behavior that matters?

### Architect

Challenge structural fitness.

Ask:

- Does the design serve the stated goal, or a goal the author assumed?
- Where do responsibilities leak across boundaries?
- Which coupling points will hurt when requirements shift?
- What implicit assumptions about scale, concurrency, persistence, or ownership will break first?
- Are APIs, schemas, contracts, or module boundaries coherent?

### Minimalist

Challenge necessity and complexity.

Ask:

- What can be deleted without losing the stated goal?
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

Scope:
[diff, files, PR, plan, artifact, or exact sections under review]

Evidence:
[paste or summarize the review packet; include commands already run and their relevant output]

Your lens:
[Skeptic | Architect | Minimalist]

Lens instructions:
[paste the full lens definition from this skill]

Review contract:
- Find real problems, not style preferences.
- Cite concrete files, lines, commands, artifacts, or missing evidence when possible.
- Explain the failure scenario for each finding.
- Rate severity as high, medium, or low.
- Recommend a concrete action.
- If you find no issue, say so and name the evidence that made you confident.
- Return only your review in markdown.

Output format:
## [Lens] Review
1. **[severity] Finding title**
   - Evidence:
   - Failure scenario:
   - Recommendation:
```

## Synthesis Rules

- Read every reviewer output before deciding.
- Mark missing or empty outputs in `Reviewer Setup`.
- Merge duplicate findings, preserving all lenses that raised them.
- Accept only findings that are grounded in evidence or a plausible failure path.
- Reject false positives explicitly. Adversarial reviewers are expected to overreach sometimes.
- If verification is missing, distinguish "known broken" from "not proven".

## Verdict Format

```markdown
## Intent
<what the work is trying to achieve>

## Reviewer Setup
- Lead: <current agent/tool>
- Route: <cross-tool | same-tool subagent | same-tool CLI | single-agent fallback>
- Reviewers: <lens -> tool/session/output status>
- Config posture: <normal local config loaded | custom config | unknown>
- Permission posture: <read-only | static packet | tools disabled | other>
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
- Recommendation: <specific next action>
- Lead judgment: <accept | reject> - <brief rationale>

## What Went Well
<1-3 grounded positives, or "No separate positives identified.">

## Residual Risk
<important uncertainty that remains after the review>
```

Verdict logic:

- `PASS`: no accepted high-severity findings.
- `CONTESTED`: at least one high-severity claim is plausible but disputed, unverified, or blocked by missing evidence. Also use this when multiple accepted medium findings make the work risky to ship even without a single blocker.
- `REJECT`: at least one accepted high-severity finding blocks the stated intent.

## Fallback Behavior

If no independent reviewer can be spawned, report the blocker and ask whether to use `single-agent fallback`. Only after the user requests or approves fallback should you run the lenses yourself in separate passes. Keep the verdict useful, but be explicit that independence was not achieved.

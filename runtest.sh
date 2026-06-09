#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re

root = Path("skills/adversarial-review")
skill = root / "SKILL.md"
openai_yaml = root / "agents" / "openai.yaml"
license_file = Path("LICENSE")
readme = Path("README.md")
readme_zh = Path("README-zh.md")

for path in (skill, openai_yaml, license_file):
    if not path.exists():
        raise SystemExit(f"missing required file: {path}")

skill_text = skill.read_text()
if not skill_text.startswith("---\n"):
    raise SystemExit("SKILL.md missing YAML frontmatter")

try:
    _, frontmatter, body = skill_text.split("---\n", 2)
except ValueError as exc:
    raise SystemExit("SKILL.md frontmatter is not closed") from exc

if len(frontmatter) > 1024:
    raise SystemExit(f"SKILL.md frontmatter too long: {len(frontmatter)}")

required_frontmatter = {
    "name": r"^name:\s*adversarial-review\s*$",
    "description": r"^description:\s*Use when .+",
}
for field, pattern in required_frontmatter.items():
    if not re.search(pattern, frontmatter, re.MULTILINE):
        raise SystemExit(f"SKILL.md missing valid frontmatter field: {field}")

required_sections = [
    "## Core Rules",
    "## Workflow",
    "## Reviewer Route Selection",
    "## Lenses",
    "## Reviewer Prompt Template",
    "## Verdict Format",
]
for section in required_sections:
    if section not in body:
        raise SystemExit(f"SKILL.md missing section: {section}")

route_policy_forbidden = (
    "best available route",
    "Use the first route",
    "If the route is not obvious, choose",
    "must explicitly specify the reviewer route",
    "If the user has not specified a reviewer route, stop",
    "Do not use it when the user has not specified a reviewer route",
    "必须通过用户指定",
    "不要在用户没有指定评审路径时直接使用",
)
for forbidden in route_policy_forbidden:
    for path in (readme, readme_zh, skill):
        if forbidden in path.read_text():
            raise SystemExit(f"{path} contains automatic route selection language: {forbidden}")

readme_text = readme.read_text()
for required in (
    "pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review",
    "pedronauck/skills",
    "## Reviewer Lenses",
    "## When Not To Use",
    "Skeptic",
    "Architect",
    "Minimalist",
    "At its core, the skill treats adversarial review as falsification",
    "falsifiable claim under test",
    "checks whether the work is correct, complete, and verified",
    "checks whether the structure, boundaries, and contracts fit the stated goal",
    "checks whether the work can be simpler, smaller, or less speculative",
    "If no route is named in an interactive chat, the skill shows the route options, recommends same-tool subagent, and asks before dispatching reviewers.",
    "In non-interactive automation, the default route is same-tool subagent.",
):
    if required not in readme_text:
        raise SystemExit(f"README.md missing required documentation text: {required}")

readme_section_order = (
    "## Reviewer Lenses",
    "## Reviewer Routes",
    "## When Not To Use",
)
readme_section_positions = [readme_text.find(section) for section in readme_section_order]
if any(position == -1 for position in readme_section_positions) or readme_section_positions != sorted(readme_section_positions):
    raise SystemExit("README.md sections must be ordered: Reviewer Lenses, Reviewer Routes, When Not To Use")

for forbidden in (
    "cp -R skills/adversarial-review .codex/skills/",
    "For Codex workspaces, keep the skill project-local when possible",
    "Before publishing, also verify from a fresh clone",
    "single-agent fallback",
):
    if forbidden in readme_text:
        raise SystemExit(f"README.md contains outdated documentation text: {forbidden}")

if not readme_zh.exists():
    raise SystemExit("README-zh.md missing")

readme_zh_text = readme_zh.read_text()
if "最佳路径" in readme_zh_text:
    raise SystemExit("README-zh.md contains automatic route selection language: 最佳路径")

for required in (
    "pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review",
    "pedronauck/skills",
    "## 评审视角",
    "## 何时不使用",
    "Skeptic",
    "Architect",
    "Minimalist",
    "证伪",
    "被测主张",
    "检查工作是否正确、完整，并且已经被充分验证",
    "检查结构、边界和契约是否服务于既定目标",
    "检查实现是否可以更简单、更小、更少猜测",
    "如果交互式聊天里没有指定路径，技能会列出评审路径选项，建议使用同工具 subagent，并在分派前询问用户。",
    "在非交互式自动化场景中，默认路径是同工具 subagent。",
):
    if required not in readme_zh_text:
        raise SystemExit(f"README-zh.md missing required documentation text: {required}")

readme_zh_section_order = (
    "## 评审视角",
    "## 评审路径",
    "## 何时不使用",
)
readme_zh_section_positions = [readme_zh_text.find(section) for section in readme_zh_section_order]
if any(position == -1 for position in readme_zh_section_positions) or readme_zh_section_positions != sorted(readme_zh_section_positions):
    raise SystemExit("README-zh.md sections must be ordered: 评审视角, 评审路径, 何时不使用")

for forbidden in (
    "cp -R skills/adversarial-review .codex/skills/",
    "对于 Codex workspace",
    "发布前，还要从全新克隆中验证",
    "单 agent 兜底",
):
    if forbidden in readme_zh_text:
        raise SystemExit(f"README-zh.md contains outdated documentation text: {forbidden}")

for required in (
    "Risk overrides size",
    "security, privacy, data loss, migrations, concurrency, permissions, dependency changes, or external publishing",
    "Adversarial review is a falsification exercise",
    "Do not require users to know route names before they can use this skill",
    "If no route is provided in an interactive turn, present the route options, recommend same-tool subagent, and ask before dispatching reviewers",
    "If no route is provided in a non-interactive or automation context, default to same-tool subagent",
    "Interactive mode means the lead can ask the user a follow-up and reasonably wait for an answer",
    "Claim under test",
    "success criteria",
    "failure conditions",
    "Steelman the intent before attacking it",
    "What would make the claim false?",
    "smallest counterexample",
    "Verdict impact",
    "mktemp -d -t adversarial-review.XXXXXX",
    "trap 'rm -rf \"$REVIEW_WORK_DIR\"' EXIT",
    "command -v codex",
    "command -v claude",
    "reviewer produced no output",
):
    if required not in skill_text:
        raise SystemExit(f"SKILL.md missing required workflow safeguard: {required}")

for forbidden in (
    "mktemp -d /tmp/adversarial-review.XXXXXX",
    "single-agent fallback",
    "manual fallback",
    "Fallback Behavior",
    "after a requested independent route failed",
):
    if forbidden in skill_text:
        raise SystemExit(f"SKILL.md contains outdated or unsafe workflow text: {forbidden}")

workflow_requirements = {
    "route missing asks or defaults by context": (
        "If the route is missing in an interactive turn, show the route options, recommend same-tool subagent, and ask the user to choose",
        "If the route is missing in a non-interactive or automation context, use same-tool subagent as the default route",
        "Do not silently substitute a different route",
    ),
    "reviewers are read-only by default": (
        "Reviewers must be read-only by default",
        "static review packet instead of workspace access",
    ),
    "missing reviewer output is evidence": (
        "Missing reviewer output is evidence",
        "Mark missing or empty outputs",
    ),
    "lead rejects overreaching findings": (
        "Reject false positives explicitly",
        "Adversarial reviewers are expected to overreach sometimes",
    ),
}
for requirement, snippets in workflow_requirements.items():
    for snippet in snippets:
        if snippet not in skill_text:
            raise SystemExit(f"SKILL.md missing workflow requirement ({requirement}): {snippet}")

for forbidden in (
    "/Users/yi",
    "~/.codex",
    "~/.agents",
    "brain/principles",
    "references/",
    "codex-test-hooks",
):
    if forbidden in skill_text:
        raise SystemExit(f"SKILL.md contains private or external dependency: {forbidden}")

for path in (skill, openai_yaml):
    text = path.read_text()
    try:
        text.encode("ascii")
    except UnicodeEncodeError as exc:
        raise SystemExit(f"{path} contains non-ASCII text") from exc

openai_text = openai_yaml.read_text()
for expected in (
    'display_name: "Adversarial Review"',
    'short_description: "Independent critique for code, plans, and diffs"',
    'default_prompt: "Use $adversarial-review',
):
    if expected not in openai_text:
        raise SystemExit(f"agents/openai.yaml missing expected text: {expected}")

license_text = license_file.read_text()
if not license_text.startswith("MIT License\n"):
    raise SystemExit("LICENSE must use the MIT License text")

print("skill package and workflow validation passed")
PY

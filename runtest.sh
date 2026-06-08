#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re

root = Path("skills/adversarial-review")
skill = root / "SKILL.md"
openai_yaml = root / "agents" / "openai.yaml"
license_file = Path("LICENSE")

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
)
for forbidden in route_policy_forbidden:
    for path in (Path("README.md"), skill):
        if forbidden in path.read_text():
            raise SystemExit(f"{path} contains automatic route selection language: {forbidden}")

if "user-specified route" not in Path("README.md").read_text():
    raise SystemExit("README.md must explain that reviewers run through a user-specified route")

readme_text = Path("README.md").read_text()
for required in (
    "pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review",
    "pedronauck/skills",
    "## Reviewer Lenses",
    "Skeptic",
    "Architect",
    "Minimalist",
    "checks whether the work is correct, complete, and verified",
    "checks whether the structure, boundaries, and contracts fit the stated goal",
    "checks whether the work can be simpler, smaller, or less speculative",
):
    if required not in readme_text:
        raise SystemExit(f"README.md missing required documentation text: {required}")

for forbidden in (
    "cp -R skills/adversarial-review .codex/skills/",
    "For Codex workspaces, keep the skill project-local when possible",
    "Before publishing, also verify from a fresh clone",
):
    if forbidden in readme_text:
        raise SystemExit(f"README.md contains outdated documentation text: {forbidden}")

readme_zh = Path("README-zh.md")
if not readme_zh.exists():
    raise SystemExit("README-zh.md missing")

readme_zh_text = readme_zh.read_text()
if "最佳路径" in readme_zh_text:
    raise SystemExit("README-zh.md contains automatic route selection language: 最佳路径")

if "用户指定" not in readme_zh_text:
    raise SystemExit("README-zh.md must explain that reviewers run through a user-specified route")

for required in (
    "pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review",
    "pedronauck/skills",
    "## 评审视角",
    "Skeptic",
    "Architect",
    "Minimalist",
    "检查工作是否正确、完整，并且已经被充分验证",
    "检查结构、边界和契约是否服务于既定目标",
    "检查实现是否可以更简单、更小",
):
    if required not in readme_zh_text:
        raise SystemExit(f"README-zh.md missing required documentation text: {required}")

for forbidden in (
    "cp -R skills/adversarial-review .codex/skills/",
    "对于 Codex workspace",
    "发布前，还要从全新克隆中验证",
):
    if forbidden in readme_zh_text:
        raise SystemExit(f"README-zh.md contains outdated documentation text: {forbidden}")

if "The user must explicitly specify the reviewer route" not in skill_text:
    raise SystemExit("SKILL.md must require an explicit user-specified reviewer route")

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

print("skill package validation passed")
PY

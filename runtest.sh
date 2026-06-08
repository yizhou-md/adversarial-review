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

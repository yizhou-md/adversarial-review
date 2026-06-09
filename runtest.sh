#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import re
from pathlib import Path

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

def fenced_block_after(text, marker):
    start = text.find(marker)
    if start == -1:
        raise SystemExit(f"missing fenced block marker: {marker}")
    first_fence = text.find("```", start)
    if first_fence == -1:
        raise SystemExit(f"missing opening fence after: {marker}")
    second_fence = text.find("```", first_fence + 3)
    if second_fence == -1:
        raise SystemExit(f"missing closing fence after: {marker}")
    return text[first_fence:second_fence]

def line_containing(text, needle):
    matches = [line for line in text.splitlines() if needle in line]
    if not matches:
        raise SystemExit(f"missing line containing: {needle}")
    template_matches = [line for line in matches if "<" in line and "|" in line]
    if not template_matches:
        raise SystemExit(f"missing template line containing: {needle}")
    return template_matches[0]

def exact_line_containing(text, needle):
    matches = [line for line in text.splitlines() if needle in line]
    if not matches:
        raise SystemExit(f"missing line containing: {needle}")
    return matches[0]

def reject_unqualified_claude_readonly_claims(path, text):
    safe_claude_readonly_claims = {
        "lacking a filesystem read-only sandbox",
        "tool restrictions are not filesystem sandboxes",
        "must not be reported as filesystem read-only",
        "must not be reported as filesystem read-only unless the host provides a named filesystem sandbox",
        "must not be reported as filesystem read-only.",
        "不一定拥有文件系统只读沙箱",
    }
    risky_claim = re.compile(
        r"(read[- ]only(?:\s+\w+){0,3}\s+sandbox|read[- ]only(?:\s+\w+){0,3}\s+access|read[- ]only\s+(?:workspace|worktree|checkout|environment|mode)|read[- ]only\s+file[- ]?system(?:\s+access)?|\bis\s+read[- ]only\b|filesystem read[- ]only|read[- ]only filesystem|filesystem sandbox(?:es)?|sandbox(?:ed)?\s+(?:workspace|worktree|checkout|environment)|isolated\s+sandbox|can(?:not| not|['\u2019]t)\s+(?:write|modify|edit|change)|does(?: not|n['\u2019]t)\s+have(?:\s+\w+){0,3}\s+(?:(?:write|edit|modify|change|modification)\s+)?(?:access|permission)|(?:is\s+)?unable\s+to\s+(?:write|modify|edit|change)|no (?:filesystem |file )?(?:(?:write|edit|modify|change|modification)\s+)?(?:access|permission)|lacks?(?:\s+\w+){0,3}\s+(?:(?:write|edit|modify|change|modification)\s+)?(?:access|permission)|只读沙箱|文件系统只读|只读模式|只读访问权限|无法写|不能写|无法修改|不能修改|无法编辑文件|不能编辑文件|写权限)",
        re.IGNORECASE,
    )
    paragraphs = re.split(r"\n\s*\n", text)
    previous_paragraph_mentions_claude = False
    for paragraph in paragraphs:
        lowered_paragraph = paragraph.lower()
        paragraph_mentions_claude = "claude" in lowered_paragraph
        if not paragraph_mentions_claude and not previous_paragraph_mentions_claude:
            continue
        if not risky_claim.search(paragraph):
            previous_paragraph_mentions_claude = paragraph_mentions_claude
            continue
        compact_paragraph = " ".join(paragraph.split())
        sentences = re.split(r"(?<=[.!?。])\s+", compact_paragraph)
        previous_sentence_mentions_claude = previous_paragraph_mentions_claude
        for sentence in sentences:
            lowered_sentence = sentence.lower()
            mentions_claude = "claude" in lowered_sentence
            risky_matches = list(risky_claim.finditer(sentence))
            if not risky_matches:
                previous_sentence_mentions_claude = mentions_claude
                continue
            codex_only_sentence = "codex" in lowered_sentence and not mentions_claude
            likely_refers_to_previous_subject = re.search(
                r"\b(it|this|that|they|the route|this route)\b|\b(unlike|compared with|compared to|versus|vs\.?)\s+codex\b",
                lowered_sentence,
            )
            if codex_only_sentence and not likely_refers_to_previous_subject:
                previous_sentence_mentions_claude = mentions_claude
                continue
            if not mentions_claude and not previous_sentence_mentions_claude:
                previous_sentence_mentions_claude = mentions_claude
                continue
            lowered = sentence.lower()
            safe_spans = []
            for safe_claim in safe_claude_readonly_claims:
                start = lowered.find(safe_claim.lower())
                while start != -1:
                    safe_spans.append((start, start + len(safe_claim)))
                    start = lowered.find(safe_claim.lower(), start + 1)
            for match in risky_matches:
                if not any(start <= match.start() and match.end() <= end for start, end in safe_spans):
                    raise SystemExit(f"{path} contains unqualified Claude read-only claim: {sentence}")
            previous_sentence_mentions_claude = mentions_claude
        previous_paragraph_mentions_claude = paragraph_mentions_claude

def assert_rejects_unqualified_claude_claim(sample):
    try:
        reject_unqualified_claude_readonly_claims("sample", sample)
    except SystemExit:
        return
    raise SystemExit(f"Claude read-only detector missed unsafe sample: {sample}")

def assert_allows_codex_only_claim(sample):
    try:
        reject_unqualified_claude_readonly_claims("sample", sample)
    except SystemExit as exc:
        raise SystemExit(f"Claude read-only detector rejected a Codex-only sample: {sample}") from exc

for unsafe_sample in (
    "Claude Code does not need a static packet because it has a filesystem read-only sandbox.",
    "Claude cannot write to the filesystem.",
    "Claude Code provides a read-only sandbox.",
    "Claude Code provides a read-only filesystem sandbox.",
    "Claude Code has a read only sandbox.",
    "Claude Code is read-only.",
    "Claude Code runs in read-only mode.",
    "Claude Code uses a read-only workspace.",
    "Claude Code uses a read-only worktree.",
    "Claude Code uses a read-only checkout.",
    "Claude Code uses a read-only environment.",
    "Claude Code has read-only workspace access.",
    "Claude Code has read-only access to the workspace.",
    "Claude Code has a read-only file system.",
    "Claude Code has a read only file system.",
    "Claude Code has read-only file-system access.",
    "Claude plan mode provides a filesystem sandbox.",
    "Claude Code plan mode provides a sandboxed workspace.",
    "Claude Code runs in an isolated sandbox.",
    "Claude Code can't write files.",
    "Claude Code can not write files.",
    "Claude Code can\u2019t write files.",
    "Claude Code can't modify files.",
    "Claude Code can\u2019t edit files.",
    "Claude Code cannot change files.",
    "Claude Code has no write permission.",
    "Claude Code has no file write access.",
    "Claude Code has no edit permission.",
    "Claude Code has no edit permissions.",
    "Claude Code has no edit access.",
    "Claude Code has no modification permission.",
    "Claude Code does not have write access.",
    "Claude Code does not have edit access.",
    "Claude Code doesn't have write access.",
    "Claude Code doesn\u2019t have write access.",
    "Claude Code does not have file write access.",
    "Claude Code lacks write access.",
    "Claude Code lacks file write access.",
    "Claude Code is unable to write files.",
    "Claude Code unable to edit files.",
    "Claude Code is the reviewer. It has no filesystem write access.",
    "Claude Code is the reviewer. Unlike Codex, it has no file write access.",
    "Claude Code is the reviewer. Unlike Codex, no file write access.",
    "Claude Code has a filesystem read-only sandbox; still, it must not be reported as filesystem read-only.",
    "Claude Code\nThis mode cannot edit files.",
    "### Claude Code\n\nThis route provides a filesystem read-only sandbox.",
    "Claude Code 提供文件系统只读沙箱，不需要其他保护。",
    "Claude Code 是只读模式，不能修改文件。",
    "Claude Code 无法编辑文件。",
    "Claude Code 不能编辑文件。",
    "Claude Code 没有文件系统写权限。",
):
    assert_rejects_unqualified_claude_claim(unsafe_sample)

assert_allows_codex_only_claim(
    "Claude Code tool controls are not sandboxes. Codex `--sandbox read-only` is a filesystem read-only sandbox posture."
)

for required in (
    "pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review",
    "pedronauck/skills",
    "[English](README.md) | [简体中文](README-zh.md)",
    "Ship with fewer blind spots.",
    "`adversarial-review` is a Codex skill.",
    "## What Problem It Solves",
    "## How It Works",
    "## Reviewer Lenses",
    "## Reviewer Routes (Who Reviews)",
    "## When Not To Use",
    "Skeptic",
    "Architect",
    "Minimalist",
    "falsifiable claim under test",
    "falsification",
    "Frame the hypothesis",
    "Look for independent counterexamples",
    "Decide the verdict",
    "| `Skeptic` | Checks whether the work is correct, complete, and verified. |",
    "| `Architect` | Checks whether the structure, boundaries, and contracts fit the stated goal. |",
    "| `Minimalist` | Checks whether the work can be simpler, smaller, or less speculative. |",
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
    "self-contained Codex skill",
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
    "[English](README.md) | [简体中文](README-zh.md)",
    "交付前，让另一个脑子专门找反例。",
    "## 它解决什么问题",
    "## 它是怎么工作的",
    "## 评审视角",
    "## 评审路径（谁来评审）",
    "## 何时不使用",
    "Skeptic",
    "Architect",
    "Minimalist",
    "证伪",
    "被测主张",
    "建立假设",
    "独立找反例",
    "判定结论",
    "| `Skeptic` | 检查工作是否正确、完整，并且已经被充分验证。 |",
    "| `Architect` | 检查结构、边界和契约是否服务于既定目标。 |",
    "| `Minimalist` | 检查实现是否可以更简单、更小、更少猜测，避免没有证据支撑的复杂度。 |",
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
    "codex exec --help",
    "claude --help",
    "--permission-mode plan",
    "reviewer produced no output",
    "tool restrictions are not filesystem sandboxes",
    "filesystem read-only sandbox",
    "static packet / tools disabled",
    "tool-restricted plan mode",
):
    if required not in skill_text:
        raise SystemExit(f"SKILL.md missing required workflow safeguard: {required}")

for forbidden in (
    "mktemp -d /tmp/adversarial-review.XXXXXX",
    "single-agent fallback",
    "manual fallback",
    "Fallback Behavior",
    "after a requested independent route failed",
    "Claude read-only sandbox",
    "Claude filesystem read-only",
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

claude_static_packet_requirements = (
    "static packet / tools disabled",
    "When using this static-packet example, record",
    "must not be recorded as `tool-restricted plan mode`",
    "must not be reported as filesystem read-only",
)
for snippet in claude_static_packet_requirements:
    if snippet not in skill_text:
        raise SystemExit(f"SKILL.md missing Claude permission boundary: {snippet}")

claude_static_packet_block = fenced_block_after(skill_text, "Claude static-packet reviewer example:")
for snippet in (
    "claude \\",
    "--print",
    "--no-session-persistence",
    "--output-format text",
    "--permission-mode plan",
    "--tools \"\"",
):
    if snippet not in claude_static_packet_block:
        raise SystemExit(f"Claude static-packet example missing: {snippet}")
if "--sandbox" in claude_static_packet_block:
    raise SystemExit("Claude static-packet example must not use a Codex filesystem sandbox flag")
if "--bare" in claude_static_packet_block:
    raise SystemExit("Claude static-packet example must not use --bare; load normal local config")

permission_posture_line = line_containing(skill_text, "Permission posture summary:")
for posture in (
    "filesystem read-only sandbox",
    "static packet / tools disabled",
    "tool-restricted plan mode",
    "mixed",
    "unknown",
    "other",
):
    if posture not in permission_posture_line:
        raise SystemExit(f"Permission posture summary line missing allowed posture: {posture}")

reviewers_line = exact_line_containing(skill_text, "Reviewers:")
for required in (
    "config posture",
    "permission posture",
    "output status",
):
    if required not in reviewers_line:
        raise SystemExit(f"Reviewers line must record per-reviewer {required}: {reviewers_line}")
if "/" in reviewers_line:
    raise SystemExit("Reviewers line must not use '/' as a field separator because permission posture labels may contain '/'")
if reviewers_line.count(";") < 4:
    raise SystemExit(f"Reviewers line must use semicolon-separated fields: {reviewers_line}")

if "Permission posture:" in skill_text:
    raise SystemExit("SKILL.md must use per-reviewer posture plus Permission posture summary, not the old singular field")

for required in (
    "Use `mixed` in `Permission posture summary` when reviewers used different permission postures",
    "keep each exact posture in the per-reviewer `Reviewers` entry",
):
    if required not in skill_text:
        raise SystemExit(f"SKILL.md missing mixed permission posture rule: {required}")

for required in (
    "Independence and permission state are separate",
    "tool restrictions are not filesystem sandboxes",
    "static packet / tools disabled",
    "tool-restricted plan mode",
):
    if required not in readme_text:
        raise SystemExit(f"README.md missing permission state guidance: {required}")

for required in (
    "独立性和权限状态是两件事",
    "工具限制不等于文件系统沙箱",
    "静态评审包",
    "static packet / tools disabled",
    "plan mode",
    "tool-restricted plan mode",
):
    if required not in readme_zh_text:
        raise SystemExit(f"README-zh.md missing permission state guidance: {required}")

for path, text in (
    (skill, skill_text),
    (readme, readme_text),
    (readme_zh, readme_zh_text),
):
    reject_unqualified_claude_readonly_claims(path, text)

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

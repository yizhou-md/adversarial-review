# adversarial-review

交付前，先让另一个脑子专门找反例。

`adversarial-review` 是一个自包含的 Codex 技能，用来在你相信某个结果之前，挑战代码、计划、diff、拉取请求、实现结果和 agent 输出。它不是普通的“看一眼有没有问题”，而是把问题改成：什么情况会证明这件事其实没做好？

它的核心是把对抗式评审当作一次证伪：先写出可证伪的被测主张，再让评审者或评审轮次寻找具体反例，最后判断这些反例是否改变结论。

和普通自检不同，这个技能会把独立性说清楚，但不会要求用户先记住路径名。评审者可以通过用户命名的路径运行，也可以走默认路径策略：例如由 Codex 调用 Claude Code、同一工具的 subagent、全新的同工具 CLI 会话，或者明确标注的单 agent 手动评审路径。如果交互式聊天里没有指定路径，技能会列出评审路径选项，建议使用同工具 subagent，并在分派前询问用户。在非交互式自动化场景中，默认路径是同工具 subagent。

这个技能参考了公开的 [`pedronauck/skills` `adversarial-review` skill](https://claudemarketplaces.com/skills/pedronauck/skills/adversarial-review)。它保留了好用的评审视角模式，并针对 Codex 调整了路径策略：用户可以指定评审路径；如果省略路径，就按上下文处理；技能记录独立性状态，但不按可用性替用户排序。

## 你会得到什么

- 一段清楚的评审意图，以及一个可证伪的被测主张。
- 冻结后的评审范围，避免不同评审者各看各的。
- 来自一个或多个视角的发现：`Skeptic`、`Architect` 和 `Minimalist`。
- 一个综合结论：`PASS`、`CONTESTED` 或 `REJECT`。
- 评审者设置、权限状态、缺失证据，以及主 agent 对每个已接受发现的判断。

## 目录

- `skills/adversarial-review/SKILL.md`：评审工作流、评审视角、提示词模板、综合规则和结论格式。
- `skills/adversarial-review/agents/openai.yaml`：Codex/OpenAI UI 元数据。

## 安装

使用 Agent Skills CLI 安装：

```sh
pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review
```

## 使用

告诉 agent 要评审什么。你可以指定路径，但不必先知道全部路径术语：

```text
Use $adversarial-review to review this diff with a Codex subagent and Claude Code.
```

这个技能会：

1. 把意图转成可证伪的被测主张，包括成功标准和失败条件。
2. 冻结评审范围：diff、PR、计划、文件，或其他具体材料。
3. 解析评审路径：使用你指定的路径；交互式聊天缺失路径时列出选项并询问；非交互式自动化中默认使用同工具 subagent。
4. 在路径支持时，用选定的评审视角分派评审者。
5. 合并重复发现，并判断每个发现是否改变最终结论。
6. 返回带有具体证据、失败场景和下一步建议的评审结论。

## 评审视角

- `Skeptic`：检查工作是否正确、完整，并且已经被充分验证。
- `Architect`：检查结构、边界和契约是否服务于既定目标。
- `Minimalist`：检查实现是否可以更简单、更小、更少猜测，避免没有证据支撑的复杂度。

## 评审路径

你可以指定要使用哪种路径，也可以让缺省路径策略生效。这个技能不会仅因为某条路径可用就自动选择它。

| 路径 | 示例 |
| --- | --- |
| 跨工具评审者 | Codex 调用 Claude Code，或 Claude Code 调用 Codex |
| 同工具 subagent | Codex 启动隔离的 Codex subagents |
| 同工具 CLI 会话 | Codex 启动一个新的 `codex exec` 评审者 |
| 单 agent 手动评审 | 主 agent 自己运行每个评审视角，并标注没有独立评审者 |

如果交互式聊天省略路径，技能应展示上表，建议同工具 subagent，并在分派前询问用户。在非交互式自动化中，同工具 subagent 是固定默认路径。如果指定路径或默认路径不可用，技能会报告阻塞原因，而不是静默切换到另一条路径。

默认情况下，评审工具应加载正常的用户配置和项目配置。这样可以让本地规则、团队政策和项目约定在评审期间保持生效。评审者默认仍应保持只读；如果某条路径无法被限制权限，就传入静态评审包，而不是提供 workspace 访问权限。

## 何时不使用

- 不要把这个技能用于普通快速自检；用户没有要求对抗式评审时，不应主动启动它。
- 不要把默认路径当成安装缺失工具或静默切换路径的许可。
- 不要把它当作编辑或修复流程；除非用户在评审后明确要求修复，否则这个技能只产出评审结论。
- 不要把它用于只涉及风格、格式化或 lint 清理的问题；这类任务通常不需要对抗式风险评审。

## 验证

这个仓库包含一个轻量级的包结构与工作流验证脚本。它会检查技能包结构、评审路径策略、文档和核心工作流约束；它不会真的分派 reviewer 工具。

```sh
./runtest.sh
```

## License

MIT。见 `LICENSE`。

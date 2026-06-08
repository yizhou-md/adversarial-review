# adversarial-review

交付前，先让另一个脑子专门找反例。

`adversarial-review` 是一个自包含的 Codex 技能，用来在你相信某个结果之前，挑战代码、计划、diff、拉取请求、实现结果和 agent 输出。它不是普通的“看一眼有没有问题”，而是把问题改成：什么情况会证明这件事其实没做好？

它的核心是把对抗式评审当作一次证伪：先写出可证伪的被测主张，再让评审者或评审轮次寻找具体反例，最后判断这些反例是否改变结论。

和普通自检不同，这个技能会把独立性说清楚。评审者必须通过用户指定的路径运行：例如由 Codex 调用 Claude Code、同一工具的 subagent、全新的同工具 CLI 会话，或者明确标注的单 agent 手动评审路径。如果用户还没有指定路径，技能会先询问，再分派评审者。

这个技能参考了公开的 [`pedronauck/skills` `adversarial-review` skill](https://claudemarketplaces.com/skills/pedronauck/skills/adversarial-review)。它保留了好用的评审视角模式，并针对 Codex 调整了路径策略：由用户指定评审路径，技能记录独立性状态，但不替用户给路径排序。

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

告诉 agent 要评审什么，以及走哪条评审路径：

```text
Use $adversarial-review to review this diff with a Codex subagent and Claude Code.
```

这个技能会：

1. 把意图转成可证伪的被测主张，包括成功标准和失败条件。
2. 冻结评审范围：diff、PR、计划、文件，或其他具体材料。
3. 确认用户指定的评审路径；如果缺失，先询问用户。
4. 在路径支持时，用选定的评审视角分派评审者。
5. 合并重复发现，并判断每个发现是否改变最终结论。
6. 返回带有具体证据、失败场景和下一步建议的评审结论。

## 评审视角

- `Skeptic`：检查工作是否正确、完整，并且已经被充分验证。
- `Architect`：检查结构、边界和契约是否服务于既定目标。
- `Minimalist`：检查实现是否可以更简单、更小、更少猜测，避免没有证据支撑的复杂度。

## 评审路径

用户应明确指定要使用哪种路径。这个技能不会仅因为某条路径可用就自动选择它。

| 路径 | 示例 |
| --- | --- |
| 跨工具评审者 | Codex 调用 Claude Code，或 Claude Code 调用 Codex |
| 同工具 subagent | Codex 启动隔离的 Codex subagents |
| 同工具 CLI 会话 | Codex 启动一个新的 `codex exec` 评审者 |
| 单 agent 手动评审 | 主 agent 自己运行每个评审视角，并标注没有独立评审者 |

默认情况下，评审工具应加载正常的用户配置和项目配置。这样可以让本地规则、团队政策和项目约定在评审期间保持生效。评审者默认仍应保持只读；如果某条路径无法被限制权限，就传入静态评审包，而不是提供 workspace 访问权限。

独立性和权限姿态是两件事。跨工具评审可以更独立，但不一定拥有文件系统只读沙箱；工具限制不等于文件系统沙箱，所以技能应记录真实权限姿态，而不是在结论中把它升格。对 Claude Code 来说，静态评审包加禁用工具应记录为 `static packet / tools disabled`；通过 plan mode 或工具控制访问 live workspace 时，应记录为 `tool-restricted plan mode` 或实际使用的权限姿态。

## 何时不使用

- 不要把这个技能用于普通快速自检；用户没有要求明确的对抗式评审路径时，不应主动启动它。
- 不要在用户没有指定评审路径时直接使用；应先询问要走哪条路径。
- 不要把它当作编辑或修复流程；除非用户在评审后明确要求修复，否则这个技能只产出评审结论。
- 不要把它用于只涉及风格、格式化或 lint 清理的问题；这类任务通常不需要对抗式风险评审。

## 验证

这个仓库包含一个轻量级的包结构与工作流验证脚本。它会检查技能包结构、评审路径策略、文档和核心工作流约束；它不会真的分派 reviewer 工具。

```sh
./runtest.sh
```

## License

MIT。见 `LICENSE`。

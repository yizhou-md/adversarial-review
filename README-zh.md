# adversarial-review

一个自包含的 Codex 技能，用于对代码、计划、diff、拉取请求、实现和 agent 输出进行对抗式评审。

这个技能会帮助主 agent 通过用户指定的路径分派独立评审者：例如由 Codex 调用 Claude Code 这样的跨工具方式、同一工具的 subagent 系统、全新的同工具 CLI 会话，或者明确标注的单 agent 兜底模式。如果用户还没有指定路径，agent 应该先询问，再分派评审者。

这个技能参考了公开的 [`pedronauck/skills` `adversarial-review` skill](https://claudemarketplaces.com/skills/pedronauck/skills/adversarial-review)。它保留了对抗式评审视角的模式，但针对 Codex 使用场景调整了评审路径策略：由用户选择评审路径，包括用户明确要求时使用 subagent。

## 目录

- `skills/adversarial-review/SKILL.md`：评审工作流、评审视角、提示词模板和结论格式。
- `skills/adversarial-review/agents/openai.yaml`：Codex/OpenAI UI 元数据。

## 安装

使用 Agent Skills CLI 安装：

```sh
pnpx skills add https://github.com/yizhou-md/adversarial-review --skill adversarial-review
```

如果你平时使用 `npx skills add ...` 运行 skills 安装器，也可以使用等价的 `npx` 写法。

## 使用

让你的 agent 使用这个技能：

```text
Use $adversarial-review to review this diff with a Codex subagent and Claude Code.
```

这个技能会：

1. 说明意图并冻结评审范围。
2. 确认用户指定的评审路径；如果缺失，先询问用户。
3. 在合适时为每个评审视角分派一名评审者。评审视角包括 `Skeptic`、`Architect` 和 `Minimalist`。
4. 将发现综合为 `PASS`、`CONTESTED` 或 `REJECT`。
5. 记录评审者设置、配置状态、权限状态、缺失证据和主 agent 判断。

## 评审视角

- `Skeptic`：检查工作是否正确、完整，并且已经被充分验证。
- `Architect`：检查结构、边界和契约是否服务于既定目标。
- `Minimalist`：检查实现是否可以更简单、更小，是否包含没有证据支撑的复杂度。

## 评审路径

用户应明确指定要使用哪种路径。这个技能不会仅因为某条路径可用就自动选择它。

| 路径 | 示例 |
| --- | --- |
| 跨工具评审者 | Codex 调用 Claude Code，或 Claude Code 调用 Codex |
| 同工具 subagent | Codex 启动隔离的 Codex subagents |
| 同工具 CLI 会话 | Codex 启动一个新的 `codex exec` 评审者 |
| 单 agent 兜底 | 主 agent 自己运行每个评审视角，并标注缺乏独立性 |

默认情况下，评审工具应加载正常的用户配置和项目配置。这样可以让本地规则、团队政策和项目约定在评审期间保持生效。评审者默认仍应保持只读；如果某条路径无法被限制权限，就传入静态评审包，而不是提供 workspace 访问权限。

## 验证

这个仓库包含一个轻量级验证脚本：

```sh
./runtest.sh
```

## License

MIT。见 `LICENSE`。

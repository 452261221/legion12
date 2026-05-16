# 05 多 Agent 开发规范

项目后续会使用多 agent 开发，因此必须从一开始就明确边界。多 agent 开发最怕大家同时改同一批文件，或者 UI agent 写规则、规则 agent 改界面。本文档定义角色、所有权、协作流程和验收标准。

## 总原则

1. 一个 agent 一次只负责明确边界。
2. 不跨目录顺手重构。
3. 不修改其他 agent 正在负责的文件。
4. 所有行为通过公开 API 集成。
5. 每个任务必须附带测试或验证说明。
6. 规则改动优先于 UI 花活。
7. 文档与代码同步更新。

## 推荐 Agent 角色

### 架构负责人 Agent

职责：

- 维护项目结构。
- 维护核心接口。
- 审查跨模块改动。
- 决定复杂规则的底层抽象。

主要文件：

- `docs/`
- `rules/core/`
- `rules/actions/`

避免：

- 逐张实现大量卡牌。
- 做 UI 美术细节。

### 规则核心 Agent

职责：

- `GameState`。
- 阶段机。
- 命令。
- 事件。
- 堆叠。
- 响应。
- 进攻。
- 天灾。
- 士气。
- modifier。

主要文件：

- `rules/core/`
- `rules/actions/`
- `tests/unit/`

产出要求：

- 单元测试。
- 场景测试。
- 状态 validator 更新。

### 卡牌数据 Agent

职责：

- 从 Excel/PDF/人工资料整理卡牌。
- 生成 JSON。
- 维护 card schema。
- 标注未实现效果。

主要文件：

- `data/cards/`
- `tools/import_cards/`
- `rules/core/card_database.gd`

禁止：

- 在导入数据时直接写复杂规则。
- 修改规则引擎核心。

### 卡牌效果 Agent

职责：

- 按阵营或机制实现效果。
- 拆分效果段。
- 添加 effect handler。
- 添加卡牌测试。

主要文件：

- `data/cards/`
- `rules/core/game_engine.gd`
- `tests/unit/`
- `tests/qa/`

要求：

- 每次任务只负责一个阵营或一个机制。
- 如果需要新增核心 API，先写清需求，交给规则核心 agent 或与架构负责人协调。

### UI Agent

职责：

- Godot 场景。
- 牌桌布局。
- 卡牌 View。
- 动画。
- 输入交互。
- 调试面板展示。

主要文件：

- `client/scenes/`
- `client/scripts/`
- `client/themes/`
- `client/assets/`

禁止：

- 直接修改血量、区域、卡牌状态。
- 在 UI 中实现规则判断。

### 测试 Agent

职责：

- 单元测试。
- 场景测试。
- Q&A 回归测试。
- 回放测试。
- 找边界 bug。

主要文件：

- `tests/`
- `tools/replay_runner/`

要求：

- 发现 bug 时给出最小复现 fixture。
- 不顺手改业务实现，除非任务明确要求。

### 工具 Agent

职责：

- 数据导入。
- schema 校验。
- 回放 runner。
- 卡牌文本解析辅助。
- 构筑器数据准备。

主要文件：

- `tools/`
- `data/schema/`

## 文件所有权

| 目录 | 主负责人 | 其他人可改条件 |
| --- | --- | --- |
| `docs/` | 架构负责人 | 与任务相关的小范围更新 |
| `rules/core/` | 规则核心 | 需要接口变更时协作 |
| `rules/actions/` | 规则核心 | 卡牌效果 agent 可请求新增动作 |
| `data/cards/` | 卡牌数据 | 卡牌效果 agent 可补 effects 字段 |
| `client/` | UI | 规则核心不改 |
| `tests/` | 测试 | 所有 agent 都可加相关测试 |
| `tools/` | 工具 | 不影响运行时的情况下可扩展 |

## 任务拆分模板

每个 agent 任务应包含：

```text
目标：
边界：
可修改文件：
不可修改文件：
输入资料：
需要调用的公开 API：
验收标准：
测试要求：
风险：
```

示例：

```text
目标：实现奥林匹斯神力资源基础动作。
边界：只实现资源查询、消耗、翻转，不实现具体卡牌。
可修改文件：rules/actions/morale_actions.gd, rules/core/player_state.gd, tests/unit/test_morale_actions.gd
不可修改文件：client/*
验收标准：可查询神力数量，可消耗并翻转 1 神力，测试通过。
```

## 接口变更流程

当卡牌效果需要核心没有的能力：

1. 卡牌 agent 写一个需求说明。
2. 规则核心 agent 增加原子动作。
3. 测试 agent 增加动作测试。
4. 卡牌 agent 使用新动作实现效果。

不要让卡牌效果绕过核心直接改状态。

## 提交前检查

每个 agent 完成任务前：

- 运行相关测试。
- 运行状态 validator。
- 检查是否改了无关文件。
- 更新文档。
- 给出改动摘要。
- 给出未完成风险。

## 冲突处理

若多个 agent 需要同一文件：

- 优先按功能拆成新文件。
- 使用注册表汇总。
- 不要在一个巨大文件里塞所有阵营效果。

例如：

```gdscript
# effect_registry_bootstrap.gd
AsgardEffects.register(registry)
OlympusEffects.register(registry)
OtherworldEffects.register(registry)
```

## 卡牌效果并行策略

先按机制拆，再按阵营拆。

第一批：

- 通用动作。
- 通用关键词。
- 通用测试牌。

第二批：

- 阿斯加德。
- 高天原。
- 太阳城。
- 天庭。

第三批：

- 奥林匹斯神力。
- 彼界符文。
- 彼界试炼。
- 晋升。

## UI 并行策略

UI 可拆：

- 牌桌布局。
- 卡牌 View。
- 手牌交互。
- 战场交互。
- 堆叠面板。
- 调试面板。
- 动画队列。

每个 UI agent 必须通过 `BattleController` 调规则，不直接操作状态。

## 测试并行策略

测试可拆：

- 基础状态不变量。
- 阶段机。
- 士气。
- 进攻。
- 堆叠。
- 天灾。
- Q&A。
- 卡牌效果。

测试 agent 要优先补“容易破”的机制：

- cost 与效果分离。
- 响应与无效。
- 置入不触发登场。
- 主宰区与战场区区别。
- 离场与阵亡。

## Done 标准

一个任务完成必须满足：

- 代码或文档已落地。
- 相关测试通过，或说明无法运行的原因。
- 没有破坏公开 API，除非任务要求。
- 没有修改无关文件。
- 文档同步。
- 遗留问题写清楚。

## Review 重点

审查时优先看：

- 是否有状态绕过。
- 是否有 UI 直接写规则。
- 是否有卡牌效果直接改 `GameState`。
- 是否缺测试。
- 是否破坏回放确定性。
- 是否把“置入”和“登场”混淆。
- 是否把 cost 和效果混淆。
- 是否忘记响应窗口。

## 推荐开发节奏

1. 架构负责人建骨架。
2. 规则核心 agent 完成最小规则循环。
3. UI agent 做可视化牌桌和调试面板。
4. 测试 agent 固化基础流程。
5. 卡牌数据 agent 导入所有卡牌。
6. 卡牌效果 agent 实现第一批简单牌。
7. 全体围绕回放和 Q&A 修正底层。

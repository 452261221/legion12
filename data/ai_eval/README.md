# AI Eval Suites

本目录存放 AI / LLM 固定评测套件 JSON。

## 现有套件

- `fixed_llm_smoke_suite.json`
  - 最小 fake-llm 冒烟。
- `fixed_llm_eval_suite.json`
  - 旧版 real-llm 基础评测。
- `fixed_llm_reasoning_smoke_suite.json`
  - 验证本轮改造后的 request/candidate 结构和 `llm_runtime_options` 通道。
- `fixed_llm_reasoning_suite.json`
  - 面向真实强模型的 reasoning 回归套件，重点观察：
  - `resolve_choice`
  - `end_phase` / `pass_priority`
  - 战术/效果响应
  - repair / fallback 稳定性

## 运行方式

在项目根目录执行：

```powershell
& 'D:\godot.exe' --headless --path 'e:\代码项目\十二军团' --script 'res://tools/run_ai_selfplay.gd' -- 'res://data/ai_eval/fixed_llm_reasoning_smoke_suite.json'
```

真实模型评测：

```powershell
& 'D:\godot.exe' --headless --path 'e:\代码项目\十二军团' --script 'res://tools/run_ai_selfplay.gd' -- 'res://data/ai_eval/fixed_llm_reasoning_suite.json'
```

## case 字段

- `name`
- `deck_path`
- `game_count`
- `seed_base`
- `ai_policy_mode`
- `max_steps`
- `allow_turn_limit`
- `use_real_llm`
- `fake_llm_mode`
- `llm_provider`
- `llm_runtime_options`

## llm_runtime_options

会直接透传到 `LlmProviderRegistry.resolve_runtime_options()`。

目前推荐优先使用：

- `llm_enable_thinking`
- `llm_response_max_tokens`
- `llm_model`
- `llm_base_url`
- `llm_timeout_seconds`
- `llm_request_extras`

## 结果位置

- `user://battle_logs/fixed_eval/<suite_name>/suite_summary.log`
- 每个 case 会输出独立 `engine / steps / ai` trace

## 汇总对比

固定评测跑完后，可以再执行一次汇总脚本，把一个 suite 或多个 suite 目录聚合成一份 JSON 报告，便于做改动前后对比。

汇总整个 fixed-eval 根目录：

```powershell
& 'D:\godot.exe' --headless --path 'e:\代码项目\十二军团' --script 'res://tools/summarize_ai_eval.gd'
```

只汇总单个 suite：

```powershell
& 'D:\godot.exe' --headless --path 'e:\代码项目\十二军团' --script 'res://tools/summarize_ai_eval.gd' -- 'user://battle_logs/fixed_eval/fixed_llm_reasoning_smoke_suite'
```

指定输入目录和输出文件：

```powershell
& 'D:\godot.exe' --headless --path 'e:\代码项目\十二军团' --script 'res://tools/summarize_ai_eval.gd' -- 'user://battle_logs/fixed_eval' 'user://battle_logs/fixed_eval/my_compare_report.json'
```

默认输出位置：

- `user://battle_logs/fixed_eval/ai_eval_compare_report.json`

脚本会自动识别两种输入：

- 某个具体 suite 目录
- 包含多个 suite 子目录的 fixed-eval 根目录

## 汇总指标

当前 JSON 报告会聚合这些核心字段：

- `decision_count`
  - AI 总决策次数。
- `repair_attempted_count`
  - 触发 repair 流程的次数。
- `repaired_count`
  - repair 后成功修复为合法动作的次数。
- `fallback_reason_count`
  - 因 fallback 原因放弃原始输出的次数。
- `thinking_downgraded_count`
  - 因 provider / model 不支持 `thinking` 而自动降级重试的次数。
- `command_type_counts`
  - 各命令类型分布，例如 `PassPriority`、`EndPhase`。
- `source_counts`
  - 决策来源分布，例如直接采纳、repair 后采纳等。
- `ended_reasons`
  - 每个 case 中各局结束原因统计。

控制台会额外打印一份简表，便于快速看趋势，例如：

```text
ai eval summary suites=1 output=C:/Users/LENOVO/AppData/Roaming/Godot/app_userdata/Legion12/battle_logs/fixed_eval/ai_eval_compare_report.json
[SUITE] fixed_llm_reasoning_smoke_suite cases=1 decisions=10 repair=0 fallback=0 thinking_downgraded=0 pass=6 end=1
  - case=starter_fake_smoke_reasoning_shape ok=true games=1 decisions=10 repair=0 fallback=0 thinking_downgraded=0 ended={"turn_limit":1}
```

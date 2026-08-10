---
name: claude-code-godot-memo
description: 本项目的 Claude Code Godot 开发工具全景备忘录 — 工具清单、状态、使用方式
metadata:
  type: reference
---

# Claude Code + Godot 4.x 开发工具备忘录

**更新**: 2026-06-28 | **Godot 版本**: 4.7 | **语言**: GDScript + C#

---

## 一、项目核心文档

### CLAUDE.md (项目指令设定)
项目的"宪法"文件，每次会话自动加载。定义了：

- **核心玩法**: Stacklands 堆叠机制 + 中国古代"稻鱼鸭/桑基鱼塘"闭环生态
- **卡牌架构**: BaseCard(Area2D) → 生物卡/资源卡/地貌卡，每张 ≤2 种动态属性
- **核心公式**: 5 条交互公式（生存/生长/捕食/代谢/翻塘）
- **子系统**: 动物代谢、生态平衡、水流传导、二十四节气引擎
- **编码规范**: 信号驱动、可视化调试、@export 导出、动画接口

### Memory 系统 (~/memory/)
持久化项目知识，跨会话保留。当前条目：
- [[installed-godot-plugins]] — Godot 插件清单及使用场景
- [[yard-plugin]] — YARD v1.2.0 资源数据库
- [[card-data-pipeline]] — CardDef → Registry → Spawner 完整管线
- [[godot-prompter-plugin]] — GodotPrompter v1.10.1 安装记录
- [[godot-cli-path]] — Godot 4.7 headless CLI 路径
- [[write-tool-no-uid]] — Write 工具创建的 .tres 无 UID
- [[godot-class-name-conflict]] — class_name 与内部 class 同名冲突
- [[yard-scan-requirements]] — YARD Registry 扫描条件

### Docs
- `docs/卡牌数据总表.md` — 21 张卡牌完整数值表
- `docs/CHANGELOG.md` — 开发变更记录

---

## 二、GodotPrompter — 51 个技能 + 9 个 Agent

**状态**: ✅ 已安装 (project scope, v1.10.1)  
**调用方式**: `Skill("godot-prompter:<skill-name>")`

### 技能分类速查

| 类别 | 技能 | 用途 |
|------|------|------|
| 核心编程 | gdscript-advanced, gdscript-patterns, csharp-godot, csharp-signals | GDScript 高级语法、C# 互操作 |
| 架构设计 | state-machine, event-bus, component-system, dependency-injection | FSM、信号总线、组件模式 |
| 场景组织 | scene-organization, resource-pattern, ability-system | 场景树规划、自定义 Resource |
| 输入输出 | input-handling, save-load, localization, export-pipeline | 输入系统、存档、本地化、导出 |
| UI 系统 | godot-ui, responsive-ui, hud-system, inventory-system | Control 节点、自适应布局、HUD |
| 玩法系统 | player-controller, ai-navigation, dialogue-system, procedural-generation | 角色控制、AI 导航、对话、程序化生成 |
| 视觉特效 | animation-system, tween-animation, shader-basics, particles-vfx | 动画系统、Tween、着色器、粒子 |
| 2D/3D | 2d-essentials, 3d-essentials, physics-system, camera-system | TileMap、3D 场景、物理、摄像机 |
| 音频 | audio-system | 音频总线、空间音频 |
| 多人与线程 | multiplayer-basics, multiplayer-sync, multithreading, dedicated-server | 联机、线程、专用服务器 |
| 平台 | mobile-development, xr-development | 移动端、VR/AR |
| 编辑工具 | addon-development, assets-pipeline, gdextension | 编辑器插件、资源管线、原生扩展 |
| 调试测试 | godot-debugging, godot-testing, godot-optimization, godot-code-review | 调试、GUT 测试、性能优化、代码审查 |
| 设计规划 | godot-brainstorming, godot-project-setup | 架构设计、新项目脚手架 |
| 内置插件 | beehave, limboai | Beehave/LimboAI 行为树 |

### 9 个专业 Agent

通过 `Agent` 工具调用，subagent_type 为：
- `godot-prompter:godot-game-dev` — 通用开发实现
- `godot-prompter:godot-game-architect` — 系统架构设计
- `godot-prompter:godot-code-reviewer` — 代码审查
- `godot-prompter:godot-animator` — 动画系统专家
- `godot-prompter:godot-csharp-engineer` — C# 专属开发
- `godot-prompter:godot-performance-profiler` — 性能诊断
- `godot-prompter:godot-shader-author` — 着色器编写
- `godot-prompter:godot-tools-engineer` — 编辑器插件/工具
- `godot-prompter:godot-ui-designer` — UI 设计

---

## 三、Godot MCP — 编辑器/运行时双向桥梁

**状态**: ✅ 插件已安装(editor) + ⚠️ mcp.json 已配置(需重启 Claude Code)  
**工作原理**:  
```
Claude Code ← stdio → godot-mcp npm server ← WebSocket(6550) → Godot Editor Plugin
```

### 编辑器端命令 (16 组, 60+ 个)

| 命令组 | 代表性命令 | 触发条件 |
|--------|-----------|----------|
| **Scene** | get_scene_tree, open_scene, save_scene, reload_scene | 编辑器打开 |
| **Node** | get_node_properties, find_nodes, update_node, reparent_node | 编辑器打开 |
| **Selection** | get_editor_state, get_selected_nodes, select_node, set_2d_viewport | 编辑器打开 |
| **Project** | get_project_info, get_project_settings, get_project_staleness | 编辑器打开 |
| **Debug** | run_project, stop_project, get_log_messages, get_stack_trace | 编辑器打开 |
| **Screenshot** | capture_game_screenshot, capture_editor_screenshot | 编辑器打开 |
| **Animation** | 完整 AnimationPlayer CRUD (15个命令) | 编辑器打开 |
| **Tilemap** | TileMap + GridMap 完整操作 (19个命令) | 编辑器打开 |
| **Resource** | get_resource_info | 编辑器打开 |
| **Scene3D** | get_spatial_info, get_scene_bounds | 编辑器打开 |
| **Input** | get_input_map, execute_input_sequence, type_text | **游戏运行时** |
| **Profiler** | get_performance_metrics, get_active_processes, get_signal_connections | **游戏运行时** |
| **RuntimeState** | get_runtime_state, watch_start/collect/stop | **游戏运行时** |
| **GameTime** | freeze, step, step_until, thaw, status | **游戏运行时** |
| **Exec** | exec_run, exec_list, exec_remove, exec_clear | **游戏运行时** |
| **Mesh** | validate_meshes | **游戏运行时** |

### 运行时独有能力 (Game Bridge 提供)

- **游戏时间冻结+步进**: 冻结游戏→思考→精确推进 N ms/帧→再观察
- **条件步进**: `step_until "G.wave > 5"` — 等到某个条件成立
- **输入注入**: 模拟按键/鼠标/手柄输入序列（带时间轴）
- **运行时截图**: 获取当前游戏画面 (PNG base64)
- **GDScript 热执行**: 在运行中的游戏里注入并运行代码
- **`_mcp_state()` 方法**: 在任意节点上实现此方法，Agent 即可观察运行时变量
- **性能剖析**: FPS、帧时间、渲染调用数、物理对象数等 30+ 指标
- **网格完整性**: 自动检测程序化网格的破损面

### 使用前提

1. Godot 编辑器**必须正在运行**且打开了本项目
2. 编辑器底部面板有 **MCP** 标签页，状态应为 "Connected"
3. Claude Code 重启后 MCP 工具会自动出现在工具列表中

---

## 四、Godot CLI (Headless)

**路径**: `E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`  
**主要用途**: 批量创建带 UID 的 .tres 资源文件（Write 工具创建的没有 UID）

```bash
GODOT="/e/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe"
"$GODOT" --headless --path "E:/Git/Godot/StackFarming" --script "tools/some_script.gd"
```

当前 `tools/` 目录下可放置 headless 执行脚本。

---

## 五、已安装的 Godot 编辑器插件

| 插件 | 版本 | 用途 | 使用场景 |
|------|------|------|----------|
| **YARD** | v1.2.0 | Resource 注册表，字符串 ID ↔ UID 双向映射 | 卡牌数值管理管线 |
| **Beehave** | — | 可视化行为树编辑器 | 鸭子/虫子 AI 状态机 |
| **Dialogue Manager** | — | 对话/事件弹窗系统 | 节气事件提示、声望解锁通知 |
| **Gut** | — | 单元测试框架 | 核心公式、劳作配方、税收税率测试 |
| **Phantom Camera** | — | 2D/3D 摄像机增强 | 吃虫/产蛋等动作反馈(震动) |
| **Godot MCP** | v4.1.0 | AI ↔ Godot 桥梁 (本文第三节) | 所有开发阶段 |

---

## 六、工具使用决策树

```
需要写 GDScript 代码？
├─ 不确定模式或用哪种 API → Skill("godot-prompter:<relevant-skill>")
├─ 复杂多文件任务 → Agent(subagent_type="godot-prompter:godot-game-dev")
└─ 代码写完了 → Agent(subagent_type="godot-prompter:godot-code-reviewer")

需要看/改 Godot 编辑器里的场景？
├─ 先确保 Godot 编辑器开着 + MCP 已连接
├─ 看场景结构 → godot_mcp: get_scene_tree
├─ 找节点 → godot_mcp: find_nodes
├─ 改属性 → godot_mcp: update_node
└─ 改后想验证 → godot_mcp: run_project + capture_game_screenshot

需要在运行时调试？
├─ 性能问题 → godot_mcp: get_performance_metrics
├─ 逻辑问题 → godot_mcp: game_time_freeze → step → capture_game_screenshot
├─ 等特定条件 → godot_mcp: game_time_step_until "condition"
├─ 注入测试输入 → godot_mcp: execute_input_sequence
├─ 观察变量 → 在节点上实现 _mcp_state() → godot_mcp: get_runtime_state
└─ 热修代码 → godot_mcp: exec_run

需要创建 Resource 文件 (.tres)？
├─ 少量 → Godot 编辑器中手动创建 (Ctrl+N)
└─ 批量 → Godot CLI headless --script tools/xxx.gd

需要行为树 AI？→ Beehave (Godot 编辑器内可视化编辑)

需要单元测试？→ GUT (编辑器内或 headless 运行)
```

---

## 七、当前项目关键路径速查

| 文件 | 作用 |
|------|------|
| `Scripts/base_card.gd` | 所有卡牌基类, Area2D, 堆叠+拖动逻辑 |
| `Scripts/card_def.gd` | CardDef Resource 类, 4 个 @export 字段 |
| `Scripts/card_enums.gd` | CardType/EntityId 枚举 |
| `Scripts/card_spawner.gd` | 卡牌工厂, 从 YARD Registry 取值 |
| `Scripts/container_card.gd` | 容器卡(地块/水塘)逻辑 |
| `Scripts/creature_card.gd` | 生物卡(鸭/鱼/虫)逻辑 |
| `Scripts/pest_card.gd` | 害虫卡逻辑 |
| `Scripts/tool_card.gd` | 工具卡(劳作)逻辑 |
| `Scripts/terrain_card.gd` | 地貌卡逻辑 |
| `Scripts/irrigation_manager.gd` | 水流传导系统 |
| `Scripts/solar_term_engine.gd` | 二十四节气引擎 |
| `Scripts/labor_manager.gd` | 劳作系统 |
| `Scripts/market_manager.gd` | 交易/市场系统 |
| `Scripts/main.gd` | 主场景控制器(新) |
| `data/cards/*.tres` | 21 张卡牌数值定义 |
| `cards_registry.tres` | YARD 注册表 |

**Why:** 用户要求整理"适合 Claude Code 的 Godot 开发备忘录"，汇总所有可用工具的状态和用法。

**How to apply:** 作为本项目开发时的工具选型参考。每次不知道用什么工具时，查看第六节的决策树。新工具安装后更新本文。

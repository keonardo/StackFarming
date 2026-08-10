---
name: card-data-pipeline
description: Full data pipeline — CardDef Resource → YARD Registry → CardSpawner loading with fallback
metadata:
  type: project
---

卡牌数值的完整数据管线：

**数据流**: `data/cards/*.tres` (CardDef) → YARD `cards_registry.tres` → `CardSpawner._get_vals()`

**Layer 1 — 定义层**: `Scripts/card_def.gd` — 全局类 `CardDef extends Resource`，4 个 `@export` 字段
**Layer 2 — 数据层**: `data/cards/*.tres` — 21 张卡牌定义，每张一个文件，由 Godot headless 脚本生成
**Layer 3 — 注册层**: `cards_registry.tres` — YARD Registry，扫描 `data/cards/` 目录
**Layer 4 — 消费层**: `CardSpawner._get_vals(ct)` — 优先从 Registry 读取，回退到 `_FALLBACK` 字典

**查询优先级**: Registry (`card_registry.load_entry(string_id)`) → Fallback (`_FALLBACK[ct]`)

**已删除的旧依赖**:
- `CardSpawner.game_data: GameData` — 不再使用 GameData
- `CardSpawner._BUILTIN` — 重命名为 `_FALLBACK`

**main.tscn 中配线**: `CardSpawner.card_registry = ExtResource("5_registry")` → `cards_registry.tres`

**Why:** 数值与代码分离，改数值只需编辑 .tres + Rescan，不用触碰任何脚本。

**How to apply:** 修改卡牌数值 → 在 Godot Inspector 中直接编辑对应 .tres → YARD Rescan → 运行时自动生效。[[yard-scan-requirements]] [[write-tool-no-uid]]

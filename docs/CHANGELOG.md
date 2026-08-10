# 📋 代码变更日志

## v0.12.1 — 2026-07-03 水纹边框 Shader + 距离邻接判定

### 🌊 新增：`shaders/water_ripple_border.gdshader`
- Canvas item 着色器，叠加在地貌卡 Panel 上
- 四边独立 sin 波纹动画 + 波光 shimmer
- Moisture 越高，水纹越明显（`moisture_level` uniform 驱动透明度）
- 水域(池塘/大水塘/鱼塘)蓝色调更深

### 🔧 新增：`base_card.gd` 水纹 overlay
- `get_water_overlay()` → 懒创建 ColorRect + ShaderMaterial，插入 Panel 底层
- `_update_water_overlay()` → 每帧更新 `moisture_level` = clamp(moisture, 0, 100)

### 🔧 修改：邻接判据
- `overlaps_area()` → `global_position.distance()` ≤ 250px (`connection_range`)
- 两张地貌卡靠近即视为水网相连，无需实际碰撞体接触

### 🃏 新增：开局水田
- `main.gd` — `spawn_card(3, "水田", Vector2(300, 355))` 放在池塘旁边

---

### 🌊 新增：`irrigation_manager.gd` (183行)
- **注册为 Autoload** (`/root/IrrigationManager`)
- **地貌卡注册表** — TerrainCard 进入/退出场景树时自动注册/注销
- **邻接图引擎** — 每 2s 基于 Area2D 重叠检测重建水网图
- **滋润传导** — 水源(池塘/大水塘) → 相邻水田自动补水，水田↔水田 Moisture 自动均衡
- **翻塘判定** — 水域卡粪便≥3 且无植物吸收 → 10s 警告后鱼类全灭
- **公开 API** — `get_water_sources_near(pos, range)` / `has_water_source_near(pos, range)` / `get_flow_neighbors(terrain)` / `get_flow_connections_for(terrain)` 供引水车和视觉层使用

### 🔧 改造：`terrain_card.gd`
- `_ready()` → 调用 `IrrigationManager.register_terrain(self)`
- 新增 `_exit_tree()` → 调用 `IrrigationManager.unregister_terrain(self)`

### 🔧 重构：`tool_card.gd` 引水车
- `_has_water_source_nearby()` → 优先使用 `IrrigationManager.has_water_source_near()`，保留手动遍历作为降级

### 📡 新增信号（预留视觉层）
- `moisture_flow(source, target, amount)` — 滋润传导事件
- `flow_network_changed()` — 水网拓扑变化事件

### 配置参数（Inspector 可调）
- `update_interval` = 2s — 图重建+传导间隔
- `flow_rate` = 5.0/s — 每秒传导滋润量
- `fish_pond_supplies_water` = false — 鱼塘不对外供水
- `eutrophication_feces_threshold` = 3 — 粪便数量触发预警
- `eutrophication_warning_time` = 10s — 预警持续后翻塘

---

**修复**: `labor_manager.gd:192` — Dictionary 引用类型 bug：`var recipe := _current_recipe; _current_recipe.clear()` 中 recipe 拿到引用后 `.clear()` 立即清空内容，导致 `recipe.get("result", -1)` 永远返回 `-1`，所有劳作配方（钓鱼、锄头开田、堆肥等）跑完进度条后不产任何产出物。改为 `.duplicate()` 先深拷贝再清空。

**影响**: 修复前全部 10 个劳作配方均受影响（不产产出物但仍消耗工具耐久）；修复后正常。

## v0.11.2 — 2026-06-27 最终修复：GameConfig 注入式架构
**重构**: GameConfig 从 autoload 改为注入模式 — creature_card/terrain_card 用 `get_node("/root/GameConfig")` 获取引用 → 传给 Behavior 构造器 → Behavior 通过 `cfg.xxx` 读取所有参数  
**重写**: `card_spawner.gd` — 100行整，`_make`/`_make_terrain`/`_make_tool` 三个工厂函数 + `_add_col` 碰撞体  
**重写**: `behaviors/duck_bhv.gd` (86行) / `crop_bhv.gd` (51行) / `terrain_bhv.gd` (89行) — 全部通过构造器接收 `cfg` 节点  
**修复**: `game_config.gd` — 去掉 `class_name`，保留 autoload 注册在 project.godot  
**修复**: `main.tscn` — 资源 ID 简化 (1-7)  
**总计**: 17 文件 / 2,205 行游戏逻辑 / 22 卡牌类型 / 3 行为代理 / 10 劳作配方  

## v0.11 — 2026-06-27 GameConfig 全线接线
**重写**: `behaviors/duck_bhv.gd` / `crop_bhv.gd` / `terrain_bhv.gd` — 所有硬编码常量替换为 `GameConfig.xxx` 动态读取  
**修复**: `game_config.gd` — 加回 `class_name GameConfig` 使跨文件引用可用  
**效果**: 改数值只需在编辑器点 GameConfig 节点，不再翻代码

## v0.10.1 — 2026-06-27 项目审计（本记录）

**审计时间**: 2026-06-27  
**总代码量**: 17 个 .gd 文件, 2,395 行游戏逻辑代码（不含 MCP 插件）  
**场景文件**: 7 个 .tscn  

---

## 项目全局统计

### 代码架构

```
Area2D
  └── BaseCard (504行)          — 卡牌基类: 4类语义属性+拖放+堆叠+死亡变换+动画
        ├── CreatureCard (21行)  — 薄壳分发→behavior
        ├── TerrainCard (98行)   — 薄壳+堆叠合成+查询
        ├── ToolCard (110行)     — 工具+引水车被动灌溉
        └── PestCard (37行)      — 虫(只允许叠在地貌上)

RefCounted (行为代理)
  ├── DuckBehavior (110行)      — 饥饿/产蛋/排粪/吃虫/孵化
  ├── CropBehavior (59行)       — 菰米湿润生长/菱角水域生长/虫害
  └── TerrainBehavior (121行)   — 湿润衰减/鱼塘产鱼/虫生成/粪便肥料Buff

Node (管理器)
  ├── CardSpawner (205行)       — 单例工厂, 22种卡统一spawn_card入口
  ├── MarketManager (311行)     — Node2D, Area2D出售区+购买面板+价格表
  ├── LaborManager (398行)      — Area2D劳作台, 10配方, 自动匹配+进度+循环
  ├── GameConfig (132行)        — Autoload, 全局参数(编辑器可视化)
  ├── IrrigationManager (3行)   — 占位(待重写)
  └── SolarTermEngine (3行)     — 占位(待重写)

Resource
  └── GameData (178行)          — 卡牌定义+配方+公式(编辑器.tres)
```

### 卡牌枚举 (CardType, 22种)

| 地貌 (0-3) | 生物 (10-13) | 工具 (20-24) | 资源 (30-37) |
|-----------|-------------|-------------|-------------|
| 0 池塘 | 10 鸭子 | 20 鱼竿 | 30 鱼 |
| 1 大水塘 | 11 菰米种 | 21 锄头 | 31 鸭蛋 |
| 2 鱼塘 | 12 菱角 | 22 引水车 | 32 鸭毛 |
| 3 水田 | 13 虫 | 23 堆肥箱 | 33 菰米 |
| | | 24 长工 | 34 菱角(果实) |
| | | | 35 水 |
| | | | 36 粪便 |
| | | | 37 肥料 |

### 核心公式实现 (F1-F29)

| ID | 名称 | 状态 |
|----|------|------|
| F1-F6 | 鸭子饥饿/产蛋/死亡/吃虫/孵化 | ✅ |
| F7 | 鸭子排粪(每45s) | ✅ |
| F8-F13 | 作物生长/湿润/冒虫/虫害/耐久归零 | ✅ |
| F14-F19 | 粪便Buff/引虫/虫灾/过期/销毁/肥料Buff | ✅ |
| F20-F26 | 水田衰减/浇水/水过期/鱼塘繁殖/养鸭上限/引水车 | ✅ |
| F27-F29 | 劳作产出/出售/购买 | ✅ |

### 劳作配方 (10个)

1. 鱼竿+池塘→鱼×1 (2s)
2. 鱼竿+大水塘→鱼×2 (2s)
3. 鱼竿+鱼塘→鱼×2 (1.5s)
4. 池塘(单独)→水×1 (1.5s)
5. 大水塘(单独)→水×2 (1.5s)
6. 锄头+大水塘→水田+副产物(30%池塘/20%菰米种/15%菱角) (4s)
7. 鱼塘(单独)→大水塘+鱼×2 (3s)
8. 大水塘(单独)→池塘×2 (3s)
9. 堆肥箱+粪便→肥料 (3s)
10. 粪便(单独)→销毁 (1s)

### 堆叠合成 (3个)

- 池塘+池塘→大水塘
- 大水塘+鱼+鱼→鱼塘
- 鸭子+鸭子+鸭蛋→新鸭子

### 集市价格表 (11项)

| 卡牌 | 售价 | 买价 |
|------|------|------|
| 鱼 | 3 | — |
| 鸭蛋 | 3 | — |
| 鸭毛 | 1 | — |
| 菰米 | 4 | — |
| 菱角 | 4 | — |
| 肥料 | 5 | — |
| 鱼竿 | — | 5 |
| 锄头 | — | 8 |
| 引水车 | — | 12 |
| 堆肥箱 | — | 10 |
| 长工 | — | 20 |

---

## ⬜ 未实现内容

| 系统 | 设计章节 | 缺失量 |
|------|---------|--------|
| **移动AI** | 第十章 M1-M4 | 鸭子巡逻+追虫 / 虫子爬行+追作物 / 空闲/追击状态机 / 12个移动参数 |
| **税收声望** | 第十一章 T1-T4 | 4级财富税率 / 120s自动扣税 / 声望累积 / 4级声望解锁门控 |
| **长工行为** | 第十二章 T3-T4 | 记忆配方+自动重复 / 食物消耗 / 扣工资 / 停工恢复 |
| **灌溉管理器** | (旧系统) | 占位文件，BFS灌溉传播+粪便漂移需重写 |
| **节气引擎** | (旧系统) | 占位文件，惊蛰/芒种/霜降事件需重写 |
| **GameConfig接线** | — | 参数全在game_config.gd里但代码未读取，仍用硬编码常量 |

**设计覆盖度: ~75%** 核心循环(产出一交易一劳作)已完整可用。

---

## 历史版本

### v0.10 — 2026-06-27 GameConfig+行为解耦
**新增**: `game_config.gd` (autoload), `behaviors/duck_bhv.gd`, `behaviors/crop_bhv.gd`, `behaviors/terrain_bhv.gd`  
**重写**: `creature_card.gd` → 18行薄壳, `terrain_card.gd` → 80行薄壳  
**清理**: `irrigation_manager.gd`/`solar_term_engine.gd` → 占位  
**修复**: sed坏字符, ext_resource ID冲突, `:=`类型警告, labor形状警告  
**场景**: `labor_station.tscn`

### v0.9 — 2026-06-27 引水车+粪便+肥料
**新增**: card_enums (FECES/FERTILIZER/COMPOST_BIN/LABORER)  
**扩展**: tool_card (水车被动灌溉), creature_card (排粪F7), terrain_card (粪便/肥料Buff F14-F19)  
**扩展**: card_spawner/market/labor (新卡支持)

### v0.8 — 2026-06-27 堆叠合成+拆解
**扩展**: terrain_card (池塘+池塘→大水塘, 大水塘+2鱼→鱼塘), labor拆解配方

### v0.7 — 2026-06-27 作物+水田+虫+水
**重写**: terrain_card (湿润衰减/鱼塘产鱼/虫生成/水卡灌溉)  
**扩展**: creature_card (菰米湿润生长/菱角水域生长/虫啃作物)

### v0.6 — 2026-06-27 鸭子逻辑
**重写**: creature_card (水上充饥/陆地挨饿/产蛋/吃虫/孵化)

### v0.3-v0.5 — 2026-06-27 劳作区三次重构
Area2D双槽 → 单槽Area2D → "不动卡牌"式劳作台

### v0.2 — 2026-06-27 集市+劳作区
**新增**: market_manager (CanvasLayer), labor_manager (CanvasLayer)

### v0.1 — 2026-06-27 四类卡牌基架
**新增**: card_enums+base_card+terrain_card+tool_card, 重写card_spawner

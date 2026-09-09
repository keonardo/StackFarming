# 📋 代码变更日志

## v0.17 — 2026-09-02 基础玩法架构重构（设计稿，未实现）

> 本次为**纯设计变更**，未改代码。新增两份设计文档，重构卡牌放置/合成/劳作/动物体系。

### 🗺️ 新增：`docs/基础玩法规则.md`（网格系统）
- **网格吸附**：格距 = 卡牌尺寸（80×100px 矩形），放置落定时自动吸附最近格点
- **地形尺寸占地**：地形卡有 w×h 尺寸，放网格后向右下展开成地形图案，范围内禁放其他地形
- **合成触发**：地形合成只靠「叠放在本体上」触发，落在地形范围内不触发（种植除外）
- **空位跳跃**：新合成地形自动搜索最近空区展开，优先复用原地形释放空格
- **劳作=玩家的双手**：劳作不是卡/不是站/不可购买，就是拖拽合成动作本身（移除劳作台概念，承接 v0.16 长工移除后的定位）

### 🌱 新增：`docs/容器与种植规则.md`（地形=容器）
- 每张地形卡是一个容器（占地 w×h 格），内容物按「卡型×容器型」交互
- **内容物永不触发地形合成**（唯一例外：地形×地形本体）
- 容量双轨：格容量（静态物硬上限 w×h）+ 类型上限（软上限）
- **鱼塘改造定稿**：大水塘+2鱼从堆叠合成改为**双手劳作配方**（解决内容物不触发合成与鱼塘升级的矛盾）

### 🐾 动物 Avatar 双态系统（容器规则第七节）
- 动物不是静态内容物，是**自由活物**：玩家不操作 = Avatar 精灵（自由移动，不受容器/网格限制）；玩家操作 = Card 卡牌
- 放入容器 = **指派栖息地**（不占格）；跨容器猎食允许
- 解决「移动 AI × 容器」矛盾

### 📚 文档同步
- `卡牌交互合成表.md`：触发方式统一为【容/叠/劳/食/集】；堆叠表按「地形合成/容器生长/物质效果」分类；鱼塘改造入劳作表
- `卡牌数据总表.md`：鱼塘来源/鱼用途/开局节奏同步为双手改造
- `容器与种植规则.md`：细化放置/取出、内容物互动、容量优先级

---

## v0.16 — 2026-08-29 移除长工系统 + 水稻种获取改为收获留种

### 🧹 移除：长工（LABORER, 卡号 24）
**背景**：长工作为「自动重复劳作的劳动力」在语义上与劳作系统重复，且「长工驯化菰米种」逻辑不合理（驯化是选种留种，不是体力劳动）。

**移除范围**（代码+数据+文档）：
- `card_enums.gd`：删除 `LABORER = 24` 枚举 + `default_name` 中「长工」条目
- `card_spawner.gd`：删除 fallback `24: [999.0, 0.5]` + `_TYPE_TO_ID` 的 `24: "laborer"`
- `market_manager.gd`：删除 `24: {"name":"长工","buy":20}`
- `game_config.gd`：删除 `prestige_unlock_laborer` + 👷长工 参数组（laborer_price/speed/eat_sec/wage）
- `tools/generate_card_tres.gd`：删除 laborer 生成行
- `cards_registry.tres`：删除 laborer 的 UID↔string_id 双向映射
- `data/cards/laborer.tres`：删除卡牌文件
- 三份设计文档（总表/扩展设计/交互合成表）：清除所有长工引用

**功能迁移**：
- 缫丝（蚕茧→丝绸）改由 **织机(TL9)** 承接（原有缫丝自动化）
- 水稻种获取：**集市购稻种（初始）→ 水稻成熟收获时按概率留种续种**（替代长工驯化）
- 声望解锁：L2 由「解锁长工」改为「解锁织机」

> 注：CHANGELOG 下方历史条目保留长工原记录（属当时变更事实，不篡改历史）。

---

## v0.15 — 2026-08-11 移动 AI（鸭子巡逻/追虫/归巢 + 虫子爬行/追作物）

### 🦆 新增：`behaviors/duck_bhv.gd` 移动状态机
- 状态机：`IDLE`（巡逻）/ `CHASE`（追虫）/ `RETURN`（归巢）
- **M1 鸭子空闲巡逻**：地貌范围 ±120px 随机漫步，随机转向
- **M2 鸭子追虫**：视野 150px 内发现虫 → 120px/s 冲刺 → 接触后复用 `_check_eat_bug` 吃掉
- **归巢**：无地貌且离最近水域 >`duck_return_threshold` → 主动游向最近水域；到达（≤90px）吸附栖水恢复 IDLE
- 视野检测改为全局遍历 `IrrigationManager.get_all_terrains()`，突破碰撞体重叠限制

### 🐛 新增：`pest_card.gd` 移动状态机
- 状态机：`IDLE`（爬行）/ `CHASE`（追作物）
- **M3 虫子空闲爬行**：地貌范围 ±80px 随机小步 + 偶尔停顿
- **M4 虫子追作物**：视野 80px 内发现作物 → 60px/s 爬向 → 接触后现有虫害逻辑接管

### 🔧 修改：`base_card.gd`
- 新增 `free_move` 标志：为 true 时跳过堆叠吸附 lerp，由移动 AI 控制位置（仍维护 z_index）
- `_find_best_stack_target` 地形根卡优先：生物栖息优先选地貌根，其次最近普通卡（避免鸭子叠鸭）
- `_process_mutual_pushing` 豁免地形卡：地形卡不被推挤、不参与推挤（静止锚点）

### 🐛 修复：鸭子归巢死循环（开局只会朝水走、靠近后停顿）
**根因**：开局生在地貌吸附范围外 → `terrain == null` 无条件进 RETURN，且到达水域后无过渡，停在目标 4px 处。
**修复**：RETURN 到达水域 → `stack_on` 吸附栖水 `→ IDLE`；`duck_return_threshold` 语义还原（过远才强制归巢）；无水域/目标失效→自由游。

### ⚙️ 配置：`game_config.gd` 新增 13 个移动参数
- 鸭子：`duck_idle_speed`/`duck_chase_speed`/`duck_vision_range`/`duck_terrain_boundary`/`duck_return_threshold`/`duck_terrain_clearance`
- 虫子：`bug_idle_speed`/`bug_chase_speed`/`bug_vision_range`/`bug_terrain_boundary`/`bug_terrain_clearance`
- 通用：`wander_turn_interval_min`/`wander_turn_interval_max`

### 🐛 修复：拖动卡牌时不再带动子卡 / 不参与任何卡牌交互
**原则**：卡牌被拖动时视为已从游戏体系取出（拿起，不在场上）。

**修复**（`base_card.gd`）：
- 拖动开始：摘除所有子卡（`_drop_stack_children`，保留子卡间相对栈关系），卡上的鸭/蛋等原地留下，不再跟随
- 拖动结束：地形卡回归水网（`_set_drag_system_participation`）
- 拖动中的卡不参与交互：
  - 不是其他卡的堆叠目标（`_find_best_stack_target` 跳过 `_is_dragging`）
  - 地形卡拖动期间退出 IrrigationManager（不供水/不邻接/不翻塘/不漂移）
  - AI 追踪跳过被拖的地貌（鸭子不追着被拿起的池塘游，`duck_bhv.gd`/`pest_card.gd` 避障+寻水均跳过）

### 🔧 调整：开局鸭子出生位置（`main.gd`）
- (340,340) → (310,310)、(500,340) → (335,305)，两鸭都落在池塘重叠区，开局即栖水

### 设计说明
- 生物卡保持 `stack_on` 地貌（代谢逻辑依赖 `get_terrain()`），但 `free_move=true` 时位置由 AI 控制
- 追虫/追作物是移动 AI 的 CHASE 态，接触后由现有吃虫/攻击逻辑收尾
- 软排斥避障 `_apply_terrain_avoidance`：每帧把目标位置从非自身地貌推开，叠加移动方向形成绕行

---

## v0.14 — 2026-08-11 背叛机制（鸭子超载转攻作物/鱼苗）

### 🦆 新增：`behaviors/duck_bhv.gd` 移动状态机
- 状态机：`IDLE`（巡逻）/ `CHASE`（追虫）/ `RETURN`（归巢）
- **M1 鸭子空闲巡逻**：地貌范围 ±120px 随机漫步，随机转向
- **M2 鸭子追虫**：视野 150px 内发现虫 → 120px/s 冲刺 → 接触后复用 `_check_eat_bug` 吃掉
- **归巢**：无地貌且离最近水域 >200px → 主动游向最近水域
- 视野检测改为全局遍历 `IrrigationManager.get_all_terrains()`，突破碰撞体重叠限制

### 🐛 新增：`pest_card.gd` 移动状态机
- 状态机：`IDLE`（爬行）/ `CHASE`（追作物）
- **M3 虫子空闲爬行**：地貌范围 ±80px 随机小步 + 偶尔停顿
- **M4 虫子追作物**：视野 80px 内发现作物 → 60px/s 爬向 → 接触后现有虫害逻辑接管

### 🔧 修改：`base_card.gd`
- 新增 `free_move` 标志：为 true 时跳过堆叠吸附 lerp，由移动 AI 控制位置（仍维护 z_index）

### ⚙️ 配置：`game_config.gd` 新增 11 个移动参数
- 鸭子：`duck_idle_speed`/`duck_chase_speed`/`duck_vision_range`/`duck_terrain_boundary`/`duck_return_threshold`
- 虫子：`bug_idle_speed`/`bug_chase_speed`/`bug_vision_range`/`bug_terrain_boundary`
- 通用：`wander_turn_interval_min`/`wander_turn_interval_max`

### 设计说明
- 生物卡保持 `stack_on` 地貌（代谢逻辑依赖 `get_terrain()`），但 `free_move=true` 时位置由 AI 控制
- 追虫/追作物是移动 AI 的 CHASE 态，接触后由现有吃虫/攻击逻辑收尾，不重复实现

---

## v0.14 — 2026-08-11 背叛机制（鸭子超载转攻作物/鱼苗）

### 🦆 新增：`behaviors/duck_bhv.gd` 背叛机制
- 触发条件：地块无害虫 **且** 鸭子数量 > `max_ducks_per_pond`（=2）
- 攻击目标优先级：作物种子（菰米种/菱角，有 health）→ 鱼苗（鱼，用 intensity）
- 作物种子扣 `health`，鱼苗扣 `intensity`（鱼是资源卡无 health）
- 攻击间隔 `duck_betrayal_interval`（2s），每次伤害 `duck_betrayal_damage`（15）
- 复用 `play_predation_animation`（位移攻击动画）+ `play_hit_animation`（受击红闪）
- 鱼苗 intensity ≤ 0 时销毁

### 配置参数（Inspector 可调，`GameConfig` → 鸭子组）
- `duck_betrayal_interval` = 2.0
- `duck_betrayal_damage` = 15.0
- 复用已有 `max_ducks_per_pond` = 2（此前已定义但从未接线）

### 设计说明
- 「动物数 > Capacity」采用 `max_ducks_per_pond`（语义精确），而非通用 `capacity`（池塘=4/鱼塘=10，用它会凑 5 只鸭才触发，几乎不可达）
- 鱼卡是 RESOURCE 无 health，故用 intensity 代理血量，intensity ≤ 0 销毁

---

## v0.13 — 2026-08-11 物质漂移系统（肥力/污染下游扩散）

### 🌊 新增：`irrigation_manager.gd` 物质漂移
- **上下游判定**：BFS 从水源（池塘/大水塘/鱼塘）计算水位梯度，`_water_level`（0=源头，越大越下游）
- **肥力产生**：水田上每份粪便每秒释放 `fertility_per_feces` 肥力
- **污染产生**：粪便超翻塘阈值（≥3）的部分产生污染
- **单向漂移**：肥力/污染按 `drift_transfer_ratio` 比例向上游 → 下游邻居扩散，避免回流振荡
- **自然衰减**：肥力/污染各自按 `fertility_decay`/`pollution_decay` 衰减
- **污染伤鱼**：水域污染超过 `pollution_damage_threshold` 时鱼类每秒扣 `pollution_fish_damage`
- 水质状态集中在管理器级字典（`_fertility`/`_pollution`），**不占用卡牌动态属性**（遵守极简双数值原则）

### 🌾 接入：`terrain_bhv.gd` 生长增益
- `get_growth_mult()` 增加肥力达标判断：`IrrigationManager.has_fertility_bonus(card)` → 额外 +`fertility_growth_bonus` 生长倍率

### 📡 新增公开 API
- `get_fertility(terrain)` / `get_pollution(terrain)` / `get_water_level(terrain)` / `has_fertility_bonus(terrain)`

### 配置参数（Inspector 可调，`IrrigationManager` → 物质漂移组）
- `drift_enabled` = true
- `fertility_per_feces` = 1.0 / `pollution_per_feces` = 2.0
- `fertility_decay` = 0.3 / `pollution_decay` = 0.2
- `drift_transfer_ratio` = 0.1
- `pollution_fish_damage` = 3.0 / `pollution_damage_threshold` = 6.0
- `fertility_growth_bonus` = 0.5 / `fertility_bonus_threshold` = 5.0

---

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

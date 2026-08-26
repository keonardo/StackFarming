# 📜 《堆叠农桑》项目指令设定 (Project Instructions)

## 1. 项目概况与角色定位
- **项目名称**：堆叠农桑 (Stack-Agriculture)
- **技术栈**：Godot 4.7 + GDScript + Antigravity IDE（已从 C# 全量迁移至 GDScript）
- **核心玩法**：基于《Stacklands》的堆叠机制，模拟中国古代"稻鱼鸭"与"桑基鱼塘"的闭环生态系统。
- **开发原则**：**极简数值**。每张卡牌的动态属性不得超过 2 种。

## 2. 核心卡牌架构 (Core Card Structure)
所有卡牌必须继承自 `BaseCard` (Area2D)，并严格遵守以下数值规范：

| 卡牌类别 | Value A (float) | Value B (float) | 核心职能 |
| :--- | :--- | :--- | :--- |
| **生物卡 (Bio)** | 健康值 (Health) | 进度值 (Progress) | 生长、产出、消耗资源 |
| **资源卡 (Res)** | 强度/含量 (Intensity) | 存续时间 (Duration) | 提供养分、攻击作物、作为代谢物 |
| **地貌卡 (Terrain)** | 承载力 (Capacity) | 滋润度 (Moisture) | 承载生物、判定生存状态 |
| **工具卡 (Tool)** | 耐久值 (Durability) | 效率值 (Efficiency) | 劳作合成、加速生产 |

## 3. 核心子系统逻辑要求

### A. 动物代谢与捕食系统 (Metabolism & Predation)
- **产出逻辑**：当动物卡（如 [小鸭子]）的 Progress 填满时，在当前地块实例化 [粪便卡]。
- **捕食逻辑**：动物卡须持续检测地块内的 [害虫卡]。若发现害虫，执行"捕食动画"：销毁害虫并重置动物的 Progress（模拟进食加速代谢）。
- **背叛机制**：若地块无害虫且动物数量超过 Capacity，动物将转而扣除作物或鱼苗的 Health。

### B. 生态平衡与危机 (Ecological Balance)
- **生存判定**：地块滋润度为 0 时，其上所有水生生物的 Health 随时间递减。
- **失衡危机 (翻塘)**：若地块上 [粪便卡] 过多且无植物吸收，地块进入"富营养化"状态，瞬间清空所有鱼类的 Health。
- **增益逻辑**：作物上方堆叠 [粪便卡] 时，生长进度 Progress 获得线性加速。

### C. 水流传导系统 (Irrigation Flow)
- **空间连接**：通过检测 [河道] -> [水渠] -> [农田] 的物理空间相邻性，传递"滋润"状态位。
- **物质漂移**：实现简单的上下游判定，使多余的肥力或污染随时间向下游地块扩散。

### D. 二十四节气引擎 (Solar Term Engine)
- **全局驱动**：周期性轮转节气卡（如 [惊蛰]、[芒种]）。
- **突发事件**：
  - **惊蛰**：在所有农田瞬间刷出大量 [害虫卡]。
  - **芒种**：大幅降低露天农田滋润度，强制玩家将鱼群移入 [深水鱼凼]。

## 4. 编码规范与实现细节 (Implementation Guidelines)
- **解耦设计**：使用 Godot 的 **信号 (Signal)** 驱动卡牌交互（如 `OnCardStacked`、`OnPestDetected`）。
- **可视化调试**：所有 ValueA/B 必须支持在开发模式下通过简单的 UI（如小进度条或 Label）在卡牌上实时显示。
- **资源管理**：卡牌属性定义应使用 `[Export]` 导出，方便在 IDE 中快速调整数值平衡。
- **动画逻辑**：交互（如吃虫、产粪）应预留简单的位移或缩放动画接口，以增强反馈感。

## 5. 交互公式速查 (Key Formulas)
1. **生存**：`Terrain.Moisture == 0 => Bio.Health -= DamageRate * Delta`
2. **生长**：`Bio.Progress += (BaseRate + Fertilizer.Intensity) * Delta`
3. **捕食**：`Bio(Animal) overlaps Pest => Destroy(Pest), Animal.Progress = 0`
4. **代谢**：`Animal.Progress >= Max => Instantiate(ExcrementCard)`
5. **翻塘**：`Count(Excrement) > Threshold && Count(Plants) == 0 => KillAll(Fish)`

## 6. 已落地的实现清单 (Implemented Systems)
> 本节记录超出原始设计的增量实现，随开发进度更新。

### 卡牌数据管线 (Card Data Pipeline)
- **CardDef** Resource（`Scripts/card_def.gd`）→ **YARD Registry**（`cards_registry.tres`）→ **CardSpawner**（`Scripts/card_spawner.gd`）
- 22 张卡牌的数值定义存放在 `data/cards/*.tres`，采用「字符串 ID ↔ UID」映射
- 批量生成脚本：`tools/generate_card_tres.gd`（headless）与 `tools/generate_card_excel.py`

### 集市系统 (Market) — `Scripts/market_manager.gd`
- 出售区（拖入卖出）/ 购买面板（点击展开），内置 12 种物品价格
- 金钱系统 `money` + 浮动通知文本

### 劳作系统 (Labor) — `Scripts/labor_manager.gd`
- 拖入卡牌按「工具 + 目标」配方合成，带进度条
- 内置 9 种配方 + 副产品概率机制 + 工具耐久消耗

### 行为树 (Beehave) — `Scripts/behaviors/`
- `duck_bhv.gd`：鸭子的觅食 / 产蛋 / 孵化 / 吃虫 / 产粪
- `crop_bhv.gd`：菰米 / 菱角的生长与虫害损伤
- `terrain_bhv.gd`：水田滋润衰减 / 鱼塘产鱼 / 虫害自然生成 / 粪便增益

### 节气 HUD — `Scripts/solar_term_hud.gd`
- 顶部居中面板：节气名 + 实时倒计时 + 警告闪烁 + 切入动画

### 水纹着色器 — `shaders/water_ripple_border.gdshader`
- 地貌卡滋润度可视化 overlay

### 物质漂移系统 — `Scripts/irrigation_manager.gd`
- 上下游判定：BFS 从水源算水位梯度
- 肥力/污染产生、单向下游扩散、自然衰减
- 污染超标伤鱼、肥力达标促作物生长
- 水质状态集中在管理器级字典，不占用卡牌动态属性

### 背叛机制 — `Scripts/behaviors/duck_bhv.gd`
- 地块无害虫且鸭数 > `max_ducks_per_pond` → 鸭子转攻作物种子/鱼苗
- 作物种子扣 health，鱼苗扣 intensity（鱼是资源卡无 health）

### 移动 AI — `Scripts/behaviors/duck_bhv.gd` + `Scripts/pest_card.gd`
- 鸭子：IDLE 巡逻 / CHASE 追虫 / RETURN 归巢
- 虫子：IDLE 爬行 / CHASE 追作物
- `BaseCard.free_move` 标志跳过堆叠吸附，由 AI 控制位置
- 视野检测走 `IrrigationManager` 全局遍历，突破碰撞体限制

## 7. 待实现 (Backlog)
_当前无未实现的核心子系统。_

# GameConfig.gd — autoload，在项目设置 » 检查器 » GameConfig 中可视化编辑所有游戏数据
extends Node

# ============================================================
# 🦆 鸭子
# ============================================================
@export_group("🦆 鸭子")
@export var duck_hunger_rate_water: float = 5.0
@export var duck_hunger_rate_land: float = -8.0
@export var duck_egg_rate: float = 3.0
@export var duck_egg_max: float = 100.0
@export var duck_full_threshold: float = 90.0
@export var duck_eat_bug_fill: float = 40.0
@export var duck_hatch_time: float = 45.0
@export var duck_feces_interval: float = 45.0
@export var duck_betrayal_interval: float = 2.0   ## 背叛攻击间隔（秒）
@export var duck_betrayal_damage: float = 15.0    ## 背叛每次攻击伤害

# ============================================================
# 🌾 作物
# ============================================================
@export_group("🌾 作物")
@export var crop_growth_rate: float = 2.0
@export var crop_growth_fast: float = 1.5
@export var crop_growth_slow: float = 0.5
@export var crop_moisture_fast: float = 60.0
@export var crop_moisture_slow: float = 30.0
@export var crop_dry_decay: float = 5.0
@export var crop_bug_damage: float = 5.0

# ============================================================
# 🐛 虫子
# ============================================================
@export_group("🐛 虫子")
@export var bug_spawn_sec: float = 30.0
@export var bug_spawn_pct: float = 0.40
@export var bug_max_field: int = 3
@export var bug_hp: float = 30.0
@export var bug_attack: float = 5.0

# ============================================================
# 🗺️ 地貌
# ============================================================
@export_group("🗺️ 地貌")
@export var pond_cap: float = 4.0
@export var bigpond_cap: float = 6.0
@export var fishpond_cap: float = 10.0
@export var paddy_cap: float = 4.0
@export var moisture_decay: float = 2.0
@export var fishpond_spawn_sec: float = 60.0
@export var max_ducks_per_pond: int = 2

# ============================================================
# 💩 粪便
# ============================================================
@export_group("💩 粪便")
@export var feces_life: float = 90.0
@export var feces_buff_sec: float = 20.0
@export var feces_cooldown: float = 30.0
@export var feces_buff_mult: float = 2.0
@export var feces_bug_bonus: float = 0.20
@export var feces_bug_faster: float = 10.0
@export var feces_overload: int = 3

# ============================================================
# 🧪 肥料
# ============================================================
@export_group("🧪 肥料")
@export var fert_life: float = 180.0
@export var fert_buff_sec: float = 30.0
@export var fert_buff_mult: float = 2.5
@export var fert_price: int = 5

# ============================================================
# 🛠️ 工具
# ============================================================
@export_group("🛠️ 工具")
@export var rod_dura: float = 10.0
@export var rod_price: int = 5
@export var hoe_dura: float = 15.0
@export var hoe_price: int = 8
@export var hoe_pond_pct: float = 0.30
@export var hoe_seed_pct: float = 0.20
@export var hoe_caltrop_pct: float = 0.15
@export var wheel_dura: float = 20.0
@export var wheel_sec: float = 5.0
@export var wheel_range: float = 250.0
@export var wheel_moist: float = 30.0
@export var wheel_price: int = 12
@export var cbin_dura: float = 15.0
@export var cbin_price: int = 10

# ============================================================
# 💰 集市
# ============================================================
@export_group("💰 集市售价")
@export var price_fish: int = 3
@export var price_egg: int = 3
@export var price_feather: int = 1
@export var price_grain: int = 4
@export var price_caltrop: int = 4

# ============================================================
# 🏛️ 税收与声望
# ============================================================
@export_group("🏛️ 税收")
@export var tax_interval: float = 120.0
@export var tax_free: float = 20.0
@export var tax_rate_mid: float = 0.20
@export var tax_rate_high: float = 0.30
@export var tax_rate_max: float = 0.40
@export var tax_threshold_mid: float = 50.0
@export var tax_threshold_high: float = 100.0

@export_group("⭐ 声望")
@export var prestige_unlock_compost: int = 20
@export var prestige_unlock_laborer: int = 50
@export var prestige_tax_halve: int = 100
@export var prestige_price_boost: int = 200

# ============================================================
# 👷 长工
# ============================================================
@export_group("👷 长工")
@export var laborer_price: int = 20
@export var laborer_speed: float = 0.5
@export var laborer_eat_sec: float = 120.0
@export var laborer_wage: int = 3

# ============================================================
# 🐟 鱼塘拆解：额外产鱼数量
# ============================================================
@export_group("🔧 特殊规则")
@export var fishpond_dismantle_extra_fish: int = 2

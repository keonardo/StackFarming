---
name: solar-term-hud-implementation
description: SolarTermHUD implementation details — panel layout, signal wiring, animation
metadata:
  type: project
---

SolarTermHUD (`Scripts/solar_term_hud.gd`) 已实现并挂入 `main.tscn`。

**位置**：场景顶部居中 (`position: 640, 12`)，z_index=100。

**视觉**：
- 背景 ColorRect 220×48，颜色按节气变化（平日暗灰/惊蛰深绿/芒种土金/霜降冰蓝）
- 节气名称：大字，带 emoji 图标（🐛惊蛰/🌾芒种/❄️霜降/☀平日）
- 倒计时：小字 MM:SS 格式，每帧实时刷新

**信号连接**：
- `SolarTermEngine.term_changed` → `_on_term_changed()`：停止警告、刷新面板、播放切



入动画
- `SolarTermEngine.term_warning` → `_on_term_warning()`：激活警告闪烁 + 橙色倒计时

**动画**：
- 警告闪烁：`sin(time * 8) * 0.5 + 0.5` 在暗灰→橙红间插值，约 4Hz
- 切入动画：面板缩放弹入 (1.08→1.0, Tween BACK ease)，名称黄→白渐变

**之前修复**：`solar_term_engine.gd:46` `Array` → `Array[CardEnums.SolarTerm]` 解决第 97 行 `new_term` 类型推断错误。

**待验证**：HUD 未在 Godot 编辑器中实测（.uid 文件尚未生成，main.tscn 中使用 path= 引用脚本）。启动 Godot 编辑器打开 main.tscn 会自动生成 UID。

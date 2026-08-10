---
name: godot-class-name-conflict
description: Godot doesn't allow two classes with the same class_name, including inner class and global class_name collision
metadata:
  type: feedback
---

Godot 要求所有 `class_name` 全局唯一。如果在同一个脚本文件内部定义了 `class CardDef extends Resource`（内部类），又在一个独立文件里声明 `class_name CardDef`（全局类），编辑器会报错：
```
Parse Error: Class "CardDef" hides a global script class.
```

这会导致所有依赖链（`card_spawner.gd`, `base_card.gd` 等）也编译失败。

**修复方法：**
1. 创建一个独立脚本文件声明 `class_name CardDef` 作为全局类
2. 从原脚本中删除内部的 `class CardDef` 定义
3. 让原脚本引用全局类（Godot 自动识别 `class_name`）

**Why:** Godot 的全局类注册表（`ProjectSettings.get_global_class_list()`）要求类名唯一。内部类和全局类同名时，内部类"隐藏"(hide)了全局类，导致冲突。

**How to apply:** 当需要从内部类提取为全局类时，必须同时删除旧定义。步骤：先建新文件 `class_name X`，再从旧文件中删除 `class X`。[[write-tool-no-uid]]

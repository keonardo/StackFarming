---
name: yard-scan-requirements
description: YARD Registry scanning requirements — UIDs, class restrictions, and scan directory configuration
metadata:
  type: reference
---

YARD Registry 扫描资源文件需要满足以下条件：

1. **资源文件必须有 UID** — 在 Godot 编辑器中创建的资源才有 UID，Write 工具创建的文件没有 [[write-tool-no-uid]]
2. **类限制 (Class Restriction)** — 扫描规则中指定资源类型，YARD 用 `does_resource_match_class_restrictions()` 验证。接受：
   - 全局类名（如 `CardDef`）
   - 脚本路径（带引号，如 `"res://Scripts/card_def.gd"`）
3. **扫描目录** — 必须用绝对 `res://` 路径，`DirAccess.dir_exists_absolute()` 验证
4. **属性索引** — 需要手动指定要索引的属性（如 `card_type`, `card_name`），索引后才能用 `filter()` / `where()` 查询
5. **Scan Now** — 每次新增或修改资源文件后需要重新扫描

**Why:** YARD 通过 UID 而非文件路径管理资源，这样文件移动后不会断链。扫描是从目录发现资源的机制。

**How to apply:** 用户需要在 Godot 编辑器中创建 Registry → 配置扫描规则（目录 + 类限制）→ Scan Now。资源文件必须在编辑器中创建以确保有 UID。

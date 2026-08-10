---
name: write-tool-no-uid
description: Files created via Write tool bypass Godot's ResourceUID system, can't be used by YARD Registry
metadata:
  type: feedback
---

通过 Write/Edit 工具创建的 `.tres` 资源文件**没有 UID**（`uid://` 标识符），因为 UID 是 Godot 编辑器在保存资源时通过 `ResourceUID.create_id()` 分配的。

YARD Registry 的 `add_entry()` 方法依赖 `ResourceUID.has_id()` 来验证资源，没有 UID 的资源无法注册。

**Why:** Write 工具直接写磁盘，不经过 Godot 的 `ResourceSaver.save()`，因此不会触发 UID 分配流程。

**How to apply:** 不通过 Write 工具创建 `.tres` 资源文件。告诉用户在 Godot 编辑器里手动创建（右键 → New Resource → 选择类型），编辑器会自动分配 UID。如果需要批量创建，可以考虑在编辑器内通过 GDScript 脚本调用 `ResourceSaver.save()` + `ResourceUID.create_id()`。

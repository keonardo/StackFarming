---
name: godot-cli-path
description: Godot 4.7 executable path for headless operations (generating .tres, running scripts, etc.)
metadata:
  type: reference
---

Godot 4.7 可执行文件位置：
- **路径**: `E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`
- **版本**: 4.7.stable.official.5b4e0cb0f
- **console 版**: `E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`

在 bash 下运行：
```bash
GODOT="/e/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe"
"$GODOT" --headless --path "E:/Git/Godot/StackFarming" --script "tools/some_script.gd"
```

注意：E: 盘下的 Godot exe 在 bash 中被当作**目录**处理（Godot_v4.7-stable_win64.exe 是一个文件夹，exe 在里面），路径必须加上子目录。

**Why:** 需要用 Godot --headless 模式执行 GDScript 来批量创建带 UID 的 .tres 资源文件（Write 工具无法分配 UID）。[[write-tool-no-uid]]

**How to apply:** 在 bash 中设置 `GODOT` 变量后直接调用 `"$GODOT"`。可以用此方法执行 tools/ 目录下的脚本。

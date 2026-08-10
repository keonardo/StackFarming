---
name: godot-prompter-plugin
description: GodotPrompter v1.10.1 Claude Code plugin — 51 Godot 4.x skills installed at project scope
metadata:
  type: reference
---

GodotPrompter v1.10.1 已安装，scope: project。

**安装方式：**
```bash
git clone https://github.com/jame581/GodotPrompter.git .claude/GodotPrompter
claude plugins marketplace add ./.claude/GodotPrompter
claude plugins install godot-prompter@godot-prompter-marketplace --scope project
```

**使用方式：** 通过 `Skill` 工具调用，格式 `Skill("godot-prompter:<skill-name>")`

**51 个技能**覆盖：状态机、存档、UI、动画、物理、2D/3D、着色器、音频、多人联机、本地化、性能优化等。同时提供 9 个专用 Agent。

市场名：`godot-prompter-marketplace`，插件在 `.claude/GodotPrompter/` 目录下。

**Why:** 用户指出这个项目，安装后可以给 AI 提供 Godot 专属开发指导。

**How to apply:** 在需要 Godot 特定模式指导时，用 `Skill` 工具调用对应技能，如 `Skill("godot-prompter:state-machine")`、`Skill("godot-prompter:save-load")` 等。

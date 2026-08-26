---
name: version-memo-rule
description: 所有代码/设计改动无论是否推送 Git 都必须写版本备忘
metadata:
  type: feedback
---

任何涉及代码或设计的改动，无论是否已推送到 Git，都必须创建对应的 memory 文件记录：
- 改了什么、为什么改
- 涉及的文件和关键决策
- 与其他系统的关联（用 `[[]]` 链接）

**Why:** Git commit message 只记录"做了什么"，版本备忘记录"为什么这样做"以及设计决策的上下文。git log 在长时间跨度下难以还原推理过程。

**How to apply:** 每次完成一个功能/修复后，主动检查是否需要新建或更新 memory 文件，并更新 `MEMORY.md` 索引。不依赖用户提醒。

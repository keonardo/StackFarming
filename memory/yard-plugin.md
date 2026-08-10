---
name: yard-plugin
description: YARD (Yet Another Resource Database) v1.2.0 installed for managing game resources with stable string IDs and runtime queries
metadata:
  type: reference
---

YARD v1.2.0 by Elliot Fontaine is installed at `addons/yard/`.

**What it does:** Creates registries of Resource files with stable string IDs. Supports:
- Bidirectional mapping between string IDs (e.g. "card_duck") and UIDs
- Property indexing for fast runtime queries without loading resources
- `Filter(property, criterion)` / `Where(criteria)` queries
- Threaded loading via `LoadAllThreadedRequest()`
- C# API at `YARD.Registry<T>` and GDScript API (same methods)

**Architecture:** Each card/entity definition is an individual `.tres` Resource file. YARD scans directories and builds a registry that maps stable string IDs to these resources.

**Usage pattern:**
```gdscript
var registry = preload("res://data/card_registry.tres")
var duck_def = registry.load_entry("card_duck")  # loads the CardDef resource
```

**Why:** User installed this to manage card data resources instead of hardcoding stats in scripts. [[game-data-architecture]] covers the resource class design.

**How to apply:** Create one `.tres` per card type, use YARD to build a registry, query at runtime via string IDs.

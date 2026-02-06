---
name: xiandao-forging
description: This skill should be used when working with the forging/duanzao system in xiandao. Use this when you need to understand equipment crafting, material processing, or create new forging recipes. Covers the complete workflow from materials to finished equipment.
version: 1.0.0
---

# Xiandao Forging System (锻造系统)

This skill provides comprehensive guide for the forging (duanzao) system in xiandao.

## Overview

The forging system allows players to craft and upgrade equipment using various materials.

**Daemon Location**: `gamelib/single/daemons/duanzaod.pike`

## Forging Process

### Material Types

1. **Ores (矿石)** - Base materials
2. **Gems (宝石)** - Enhancement materials
3. **Recipes (配方)** - Crafting patterns

### Forging Steps

1. **Decompose (分解)** - Break down items for materials
2. **Smelt (熔炼)** - Process ores
3. **Forge (锻造)** - Create equipment
4. **Enhance (强化)** - Improve stats

## Key Functions

### Material Processing

```pike
// Decompose item
array(mapping) decompose_item(object item)

// Smelt ore
object smelt_ore(string ore_id, int quantity)

// Get material value
int query_material_value(string material_id)
```

### Equipment Forging

```pike
// Forge equipment
object forge_equip(mapping materials, string recipe_id)

// Get forging cost
int query_forging_cost(string recipe_id)

// Check success rate
int query_success_rate(object player, string recipe_id)
```

### Enhancement

```pike
// Enhance equipment
int enhance_equip(object equip, object gem)

// Get enhancement bonus
mapping query_bonus(int level)
```

## Recipe Structure

```pike
// Recipe data
mapping(string:mapping) recipes = ([
    "sword_01": ([
        "name": "铁剑",
        "level": 10,
        "materials": ([
            "iron": 5,
            "coal": 2,
        ]),
        "stats": ([
            "attack": 10,
            "durability": 100,
        ]),
    ])
]);
```

## File Paths Reference

| Type | Path |
|------|------|
| Daemon | `gamelib/single/daemons/duanzaod.pike` |
| Recipes | `gamelib/data/material/duanzao.csv` |
| Materials | `gamelib/clone/item/material/` |
| Commands | `gamelib/cmds/duanzao*.pike`, `gamelib/cmds/viceskill_duanzao*.pike` |

## Usage Examples

```pike
// Check if can forge
if(DUANZAOD->can_forge(me, recipe_id)) {
    // Attempt forging
    object equip = DUANZAOD->forge_equip(me, recipe_id);
    if(equip) {
        me->add_item(equip);
    }
}

// Get material count
int iron_count = DUANZAOD->query_material_count(me, "iron");

// Decompose item
array(mapping) mats = DUANZAOD->decompose_item(old_equip);
```

## Best Practices

1. **Validate materials** before forging
2. **Handle failure cases** - equipment may be destroyed
3. **Balance success rates** based on player level
4. **Log forging activities** for anti-abuse
5. **Provide feedback** on forging results

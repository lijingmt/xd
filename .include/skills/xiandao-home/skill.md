---
name: xiandao-home
description: This skill should be used when working with the home/building system in xiandao. Use this when you need to understand how homes work, manage player homes, or create new home features. Covers home creation, room management, shop system, and furniture.
version: 1.0.0
---

# Xiandao Home System (家园系统)

This skill provides comprehensive guide for the home/building system in xiandao.

## Overview

The home system allows players to own and customize their own homes with various rooms and buildings.

**Daemon Location**: `gamelib/single/daemons/homed.pike`

## Home Structure

### Home Data

```pike
// Home mapping structure
mapping(string:mapping) homes = ([
    userid: ([
        "name": "家园名称",
        "level": 1,
        "rooms": (["room_id": room_data]),
        "shops": ([]),
    ])
]);
```

## Key Commands

### Home Management Commands

| Command | File | Purpose |
|---------|------|---------|
| home_enter | - | Enter home |
| home_buy_shop | - | Buy shop |
| home_knock_door | home_knock_door.pike | Visit other's home |
| home_move | home_move.pike | Move between rooms |
| home_functionroom_* | home_functionroom_*.pike | Function room operations |
| home_shop_* | home_shop_*.pike | Shop operations |

## Home Features

### Room Types

1. **Living Room** - Main room
2. **Bedroom** - Resting
3. **Shop** - Sell items
4. **Garden** - Plant herbs
5. **Kitchen** - Cooking
6. **Practice Room** - Training

### Shop System

Players can open shops in their homes:

```pike
// Buy shop license
int buy_shop_license(object player, string shop_type)

// Add item to shop
int add_shop_item(object player, object item, int price)

// Remove item from shop
int remove_shop_item(object player, string item_id)

// Shop transaction
int buy_from_shop(object buyer, string shop_id, string item_id)
```

### Furniture System

```pike
// Add furniture
int add_furniture(object player, string room_id, string furniture_id)

// Remove furniture
int remove_furniture(object player, string room_id, string furniture_id)

// Query furniture
mapping query_furniture(string room_id)
```

## File Paths Reference

| Type | Path |
|------|------|
| Daemon | `gamelib/single/daemons/homed.pike` |
| Commands | `gamelib/cmds/home_*.pike` |
| Data | `data_xiand/home/` |
| Furniture | `gamelib/clone/item/home/furniture/` |

## Usage Examples

```pike
// Get player's home
mapping my_home = HOMED->query_home(me->name);

// Check if has shop
if(HOMED->has_shop(me->name)) {
    // Shop operations
}

// Enter friend's home
HOMED->enter_home(me, friend_name);
```

## Best Practices

1. **Validate home ownership** before allowing modifications
2. **Check player level** for home level requirements
3. **Use locks** for concurrent modifications
4. **Save data** after any home changes
5. **Notify players** of home visitors

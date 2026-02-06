---
name: xiandao-daemons
description: This skill should be used when working with any daemon processes in the xiandao (xd) project. Use this when you need to understand how daemons work, access daemon functions, or create new daemons. Covers all daemons in gamelib/single/daemons/ and lowlib/wapmud2/single/.
version: 1.0.0
---

# Xiandao Daemons System (守护进程)

This skill provides comprehensive guide for all daemon processes in the xiandao MUD game.

## Overview

Daemons are long-running processes that manage various game systems. They are located in `gamelib/single/daemons/` and follow the naming convention `*d.pike` (e.g., `userd.pike`, `itemsd.pike`).

**Daemon Location**: `gamelib/single/daemons/`

## Daemon Structure

### Basic Daemon Template

```pike
#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

// Private variables
private mapping data = ([]);

void create()
{
    // Initialize
}

// Query function
string query_info(string id)
{
    if(data[id]) return data[id];
    return "unknown";
}

// Modify function
int set_info(string id, string value)
{
    data[id] = value;
    return 1;
}
```

## Core Daemons

### USERD - User Data Management

**File**: `userd.pike`

**Purpose**: Player login, logout, daily checks

**Key Functions**:
```pike
void do_login(object me)
void do_remove(object me)
void check_daily(object me)
```

**Usage**:
```pike
// Trigger daily check on login
USERD->do_login(this_player());

// Handle player removal
USERD->do_remove(this_player());
```

### TOPTEN - Ranking System

**File**: `topten.pike`

**Purpose**: Leaderboards for various stats (荣誉, PK, etc.)

**Usage**:
```pike
// Query top players
array(mapping) top_list = TOPTEN->query_topten_infos("daoheng");
```

### ITEMSD - Item System

**File**: `itemsd.pike`

**Purpose**: Item database, equipment generation

**Usage**:
```pike
// Get equipment by level
object equip = ITEMSD->query_equip(level, "weapon");

// Get random item
object item = ITEMSD->get_random_item(min_level, max_level);
```

### HOMED - Home System

**File**: `homed.pike`

**Purpose**: Home/building management

**See `xiandao-home` skill for details.**

### FBD - Dungeon/Instance System

**File**: `fbd.pike`

**Purpose**: Dungeon instances, team management

**See `xiandao-dungeon` skill for details.**

### DUANZAOD - Forging System

**File**: `duanzaod.pike`

**Purpose**: Equipment forging

**See `xiandao-forging` skill for details.**

## Feature Daemons

### AUTOLEARND - Auto Learning

**File**: `autolearnd.pike`

**Purpose**: AFK skill learning system

### BROADCASTD - Broadcasting

**File**: `broadcastd.pike`

**Purpose**: System broadcasts to players

### CHATROOMD - Chat System

**File**: `chatroomd.pike` / `chatroom2d.pike`

**Purpose**: Guild chat, world chat, private messages

### CITYD - City System

**File**: `cityd.pike`

**Purpose**: City management, city war

### CROND - Scheduled Tasks

**File**: `crond.pike`

**Purpose**: Cron-like scheduler for timed events

### LOTTERYD - Lottery System

**File**: `lotteryd.pike`

**Purpose**: Lottery/draw system

### MESSAGED - Messages

**File**: `messaged.pike`

**Purpose**: Message handling between players

### PAIHANGD - Rankings

**File**: `paihangd.pike`

**Purpose**: Player rankings and leaderboards

### RONGJIAND - Melting System

**File**: `rongjied.pike`

**Purpose**: Equipment melting/recycling

### RONGLIAND - Refining System

**File**: `rongliand.pike`

**Purpose**: Skill/equipment refining

### STORYD - Story System

**File**: `storyd.pike`

**Purpose**: Story progression tracking

### TASKD - Task System

**File**: `taskd.pike`

**Purpose**: Task management

**See `xiandao-task` skill for details.**

### VIPD - VIP System

**File**: `vipd.pike`

**Purpose**: VIP level management

### YUSHID - Jade System

**File**: `yushid.pike`

**Purpose**: Jade/currency system

## Utility Daemons

### COUNTD - Counters

**File**: `countd.pike`

**Purpose**: Various counters

### LOG - Logging

**File**: `log.pike`

**Purpose**: Logging system

### MAPD - Map System

**File**: `mapd.pike`

**Purpose**: World map

### TIMED - Time System

**File**: `timesd.pike`

**Purpose**: Game time management

## Daemon Access Pattern

### Global Daemon Access

All daemons are accessible via uppercase global variables:

```pike
// Access daemons directly
object room = FBD->query_fb_room("wukongta", 0, "team_id", 0);
int vip_level = VIPD->query_szx_grade(me);
```

### Daemon Initialization

Daemons auto-load on first access. Manual loading:

```pike
object daemon = find_object(ITEMSD);
if(!daemon) {
    daemon = load_object(ROOT + "gamelib/single/daemons/itemsd.pike");
}
```

## Common Patterns

### Read-Write Pattern

Many daemons persist data to files:

```pike
private mapping data = ([]);

void read_write(mapping data)
{
    string file = ROOT + "gamelib/data/mydata.csv";
    string content = Stdio.read_file(file);
    if(content) {
        // Parse and load
    }
}

void save_data()
{
    string content = "";
    foreach(data; string key; mixed value) {
        content += key + ":" + (string)value + "\n";
    }
    Stdio.write_file(ROOT + "gamelib/data/mydata.csv", content);
}
```

## File Paths Reference

| Daemon Type | Data File Path |
|-------------|----------------|
| User data | `data_xiand/` |
| Config | `gamelib/data/*.csv` |
| Logs | `log/*.log` |

## Quick Reference

| Daemon | Purpose | Global Variable |
|--------|---------|-----------------|
| USERD | User data | USERD |
| TOPTEN | Rankings | TOPTEN |
| ITEMSD | Items | ITEMSD |
| HOMED | Home | HOMED |
| FBD | Dungeons | FBD |
| TASKD | Tasks | TASKD |
| AUTOLEARND | Auto learning | AUTOLEARND |
| BROADCASTD | Broadcasts | BROADCASTD |
| VIPD | VIP | VIPD |

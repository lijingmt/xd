---
name: xiandao-dungeon
description: This skill should be used when working with the dungeon/instance system in xiandao. Use this when you need to understand how dungeons work, create new dungeons, or modify dungeon behavior. Covers instances, team management, and boss encounters.
version: 1.0.0
---

# Xiandao Dungeon System (副本系统)

This skill provides comprehensive guide for the dungeon/instance system in xiandao.

## Overview

The dungeon system manages instances, teams, and boss encounters for group content.

**Daemon Location**: `gamelib/single/daemons/fbd.pike`

## Dungeon Structure

### Dungeon Data

```pike
// Team to room mapping
mapping(string:array(object)) fb_map = ([]);

// Dungeon name to room files
mapping(string:array(string)) fb_room = ([]);

// Leave destination
mapping(string:string) fb_leave = ([]);

// Dungeon members
mapping(string:mapping(string:int)) fb_members = ([]);
```

## Key Functions

### Dungeon Entry

```pike
// Get/create dungeon room
object query_fb_room(string fb_name, int room_num, string team_id, int flag)

// Add member to dungeon
void add_fb_members(string fb_id, string player_name)

// Check if player in dungeon
int in_dungeon(object player)
```

### Team Management

```pike
// Create team
string create_team(object leader)

// Join team
int join_team(string team_id, object player)

// Leave team
int leave_team(string team_id, object player)

// Disband team
int disband_team(string team_id)
```

## Dungeon Types

### Story Dungeons (剧情副本)

- Single player or team
- Progressive rooms
- Boss at end

### Challenge Dungeons (挑战副本)

- Higher difficulty
- Better rewards
- Limited entries per day

### Time-Limited Dungeons (限时副本)

- Time limit
- Score-based rewards

## File Paths Reference

| Type | Path |
|------|------|
| Daemon | `gamelib/single/daemons/fbd.pike` |
| Dungeons | `gamelib/d/*/fb/` |
| Boss NPCs | `gamelib/clone/npc/boss/` |
| Commands | `gamelib/cmds/*fb*.pike` |

## Usage Examples

```pike
// Create dungeon room for team
object room = FBD->query_fb_room("wukongta", 0, team_id, 0);

// Add player to dungeon
FBD->add_fb_members(dungeon_id, me->name);

// Get dungeon exit
string exit = FBD->fb_leave[dungeon_id];
```

## Best Practices

1. **Validate team size** before entry
2. **Check level requirements** for dungeons
3. **Handle disconnects** gracefully
4. **Clean up empty dungeons** periodically
5. **Log dungeon completions** for analytics

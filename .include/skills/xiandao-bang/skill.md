---
name: xiandao-bang
description: This skill should be used when working with the guild (bang) system in xiandao. Use this when you need to understand how guilds work, manage guilds, or create new guild features. Covers guild creation, member management, guild chat, and guild wars.
version: 1.0.0
---

# Xiandao Guild System (帮派系统)

This skill provides comprehensive guide for the guild (bangpai) system in xiandao.

## Overview

The guild system allows players to create and manage guilds with various features.

**Daemon Location**: `lowlib/wapmud2/single/bangd.pike`

## Guild Structure

### Guild Data

```pike
// Guild mapping
mapping(string:mapping) bangs = ([
    bang_id: ([
        "name": "帮派名称",
        "leader": "帮主ID",
        "level": 1,
        "members": ([member_id: rank]),
        "money": 0,
        "exp": 0,
    ])
]);
```

## Ranks

| Rank | Chinese | Permissions |
|------|---------|-------------|
| 1 | 帮主 | Full control |
| 2 | 副帮主 | Management |
| 3 | 长老 | Limited management |
| 4 | 精英 | Member+ |
| 5 | 成员 | Basic member |

## Key Commands

| Command | Purpose |
|---------|---------|
| bang_create | Create guild |
| bang_accept | Accept invitation |
| bang_view_members | View members |
| bang_readme | Guild description |
| bang_change_desc | Update description |

## Key Functions

### Guild Management

```pike
// Create guild
int create_guild(object player, string name)

// Join guild
int join_guild(object player, string guild_id)

// Leave guild
int leave_guild(object player)

// Kick member
int kick_member(string guild_id, string member_id)

// Promote/demote
int set_rank(string guild_id, string member_id, int rank)
```

### Guild Chat

```pike
// Send guild message
void guild_chat(object player, string message)

// Guild channel
mapping guild_members = BANGD->query_guild_members(guild_id);
foreach(guild_members; string member_id; int rank) {
    object ob = find_player(member_id);
    if(ob) {
        tell_object(ob, message);
    }
}
```

## File Paths Reference

| Type | Path |
|------|------|
| Daemon | `lowlib/wapmud2/single/bangd.pike` |
| Commands | `gamelib/cmds/bang_*.pike` |
| Data | `data_xiand/bangpai/` |

## Usage Examples

```pike
// Get player's guild
string guild_id = me->query_bang_id();

// Get guild info
mapping guild = BANGD->query_guild(guild_id);

// Check if is leader
if(BANGD->is_leader(guild_id, me->name)) {
    // Leader permissions
}

// Send guild message
BANGD->guild_chat(guild_id, me->query_name_cn() + ": " + message);
```

## Best Practices

1. **Validate permissions** before guild operations
2. **Handle guild disbanding** - transfer or kick all members
3. **Use transactions** for guild money operations
4. **Log important actions** (kicks, promotions)
5. **Notify all members** of important events

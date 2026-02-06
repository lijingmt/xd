---
name: xiandao-task
description: This skill should be used when working with the task/quest system in xiandao. Use this when you need to understand how tasks work, create new tasks, or modify task behavior. Covers daily tasks, story tasks, and achievement tracking.
version: 1.0.0
---

# Xiandao Task System (任务系统)

This skill provides comprehensive guide for the task/quest system in xiandao.

## Overview

The task system manages player quests, daily tasks, and achievements.

**Daemon Location**: `gamelib/single/daemons/taskd.pike`

## Task Types

### Daily Tasks (每日任务)

- Reset daily
- Give rewards on completion
- Track completion progress

### Story Tasks (剧情任务)

- Linear progression
- One-time completion
- Unlock new areas/content

### Achievement Tasks (成就任务)

- Long-term goals
- Special rewards
- Bragging rights

## Task Structure

```pike
// Task data
mapping(string:mapping) tasks = ([
    task_id: ([
        "name": "任务名称",
        "type": "daily|story|achievement",
        "description": "任务描述",
        "requirements": ([
            "kill_monster": 10,
            "collect_item": "herb_01",
        ]),
        "rewards": ([
            "exp": 1000,
            "money": 500,
            "items": ({ "item_01", "item_02" }),
        ]),
        "prerequisites": ({ "task_001" }),
    ])
]);
```

## Key Functions

### Task Management

```pike
// Accept task
int accept_task(object player, string task_id)

// Complete task
int complete_task(object player, string task_id)

// Cancel task
int cancel_task(object player, string task_id)

// Check task progress
mapping query_task_progress(object player, string task_id)
```

### Progress Tracking

```pike
// Update kill progress
void update_kill_progress(object player, string monster_id)

// Update collection progress
void update_collect_progress(object player, string item_id)

// Check if requirements met
int check_requirements(object player, string task_id)
```

## File Paths Reference

| Type | Path |
|------|------|
| Daemon | `gamelib/single/daemons/taskd.pike` |
| Task Data | `gamelib/data/task/` |
| Commands | `gamelib/cmds/task_*.pike`, `lowlib/wapmud2/cmds/task*.pike` |

## Usage Examples

```pike
// Accept daily task
TASKD->accept_task(me, "daily_kill_10");

// Check progress
mapping progress = TASKD->query_task_progress(me, "daily_kill_10");
if(progress["completed"]) {
    // Get rewards
    TASKD->complete_task(me, "daily_kill_10");
}

// Update on monster kill
TASKD->update_kill_progress(me, monster_id);
```

## Best Practices

1. **Reset daily tasks** at midnight
2. **Validate prerequisites** before task acceptance
3. **Give appropriate rewards** based on difficulty
4. **Track task history** for analytics
5. **Notify players** of task updates

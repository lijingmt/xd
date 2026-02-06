---
name: xiandao-syntax
description: This skill should be used when writing or modifying Pike code in the xiandao (xd) project. Use this for understanding Pike language syntax, types, operators, and best practices. Covers variable declaration, functions, mappings, arrays, string operations, and common patterns used in WAPMUD.
version: 1.0.0
---

# Xiandao Pike Syntax

This skill provides comprehensive Pike language reference for the xiandao MUD game development.

## Basic Syntax

### Hello World

```pike
int main()
{
    write("Hello, World!\n");
    return 1;
}
```

### Comments

```pike
// Single line comment

/*
 * Multi-line comment
 */

/**
 * Documentation comment (often used for function headers)
 * @param param_name Description
 * @return Description
 */
```

## Variables and Types

### Basic Types

| Type | Description | Example |
|------|-------------|---------|
| `int` | Integer | `int x = 42;` |
| `float` | Floating point | `float pi = 3.14;` |
| `string` | Text string | `string s = "hello";` |
| `array` | Array/list | `array(int) arr = ({1, 2, 3});` |
| `mapping` | Hash table/dict | `mapping(string:int) m = ([]);` |
| `object` | Object reference | `object obj = this_player();` |
| `mixed` | Any type | `mixed x = "string";` |
| `void` | No return value | `void func() {}` |

### Variable Declaration Rules

**CRITICAL**: Pike does NOT allow duplicate declarations in the same scope.

```pike
// ❌ WRONG - duplicate declaration
int my_func(string arg)
{
    if(sscanf(arg, "detail %s", string bid) == 1) {
        // Error: bid declared twice!
    }
    else if(sscanf(arg, "Detail %s", string bid) == 1) {
        // Error!
    }
}

// ✅ CORRECT - declare once at function start
int my_func(string arg)
{
    string bid;  // Declare here
    if(sscanf(arg, "detail %s", bid) == 1) {
        // ...
    }
    else if(sscanf(arg, "Detail %s", bid) == 1) {
        // ...
    }
}
```

## Arrays

### Array Literal Syntax

**CRITICAL**: Pike uses `({ })` for arrays, not `[ ]`

```pike
// ✅ CORRECT - Array syntax
array(int) empty = ({});
array(int) arr = ({1, 2, 3});
array(string) names = ({"a", "b", "c"});

// ❌ WRONG - JavaScript/C style
array(int) arr = [1, 2, 3];  // Error!
```

### Adding Elements to Arrays

```pike
// Add single element - MUST wrap in ({ })
arr += ({4});  // ✅ CORRECT

// ❌ WRONG - Cannot add value directly
arr += 4;  // Error!
arr += [4];  // Error!

// Add array to array
arr += ({5, 6});  // ✅
```

### Array Operations

```pike
// Create array
array(int) arr = ({1, 2, 3, 4, 5});

// Access
int first = arr[0];
int last = arr[-1];

// Subarray
array(int) sub = arr[1..3];  // ({2, 3, 4})

// Size
int size = sizeof(arr);

// Iterate
foreach(arr, int value) {
    write(value + "\n");
}

// With index
foreach(arr; int i; int value) {
    write(sprintf("[%d] = %d\n", i, value));
}
```

## Mappings (Hash Tables)

### Mapping Literal Syntax

**CRITICAL**: Pike uses `([ ])` for mappings, not `{ }`

```pike
// ✅ CORRECT - Mapping syntax
mapping(string:int) m = ([]);
mapping(string:int) m2 = (["apple": 1, "banana": 2]);

// ❌ WRONG - JavaScript style
mapping m = {"apple": 1};  // Error!
```

### Mapping Operations

```pike
// Create empty mapping
mapping(string:int) m = ([]);

// Access
int value = m["apple"];
int with_default = m["pear"] || 0;  // Default if not exists

// Set/Update
m["grape"] = 4;

// Delete
m_delete(m, "banana");

// Size
int size = sizeof(m);

// Iterate
foreach(m; string key; int value) {
    write(sprintf("%s: %d\n", key, value));
}
```

## Strings

### String Operations

```pike
string s = "Hello";

// Concatenation
string s2 = s + " World";

// Length
int len = sizeof(s);

// Substring
string sub = s[0..2];  // "Hel"

// Split
array(string) parts = s / " ";  // Split by space

// Join
string joined = parts * ", ";   // Join with comma

// Search
int pos = search(s, "ell");     // Returns index or -1

// Replace
string replaced = replace(s, "Hello", "Hi");
```

## Conditionals and Loops

### If/Else

```pike
if(condition) {
    // code
}
else if(other_condition) {
    // code
}
else {
    // code
}
```

### Foreach

```pike
// ✅ CORRECT - Pike foreach syntax
foreach(array(int) arr, int value) {
    write(value + "\n");
}

// With index
foreach(arr; int i; int value) {
    write(sprintf("[%d] = %d\n", i, value));
}
```

## Object-Oriented Programming

### Class Definition

```pike
inherit WAPMUD_ROOM;

protected void create()
{
    // Constructor
    name = "my_room";
    name_cn = "我的房间";
    desc = "这是一个房间。";
}

// Method
string query_desc()
{
    return desc;
}
```

### Object Operations

```pike
// Get object
object me = this_player();
object env = environment(me);

// Check type
if(objectp(obj)) {
    // Is object
}

// Check function exists
if(functionp(obj->query_name)) {
    string name = obj->query_name();
}

// Call method
string name = obj->query_name();
```

## Common Patterns in WAPMUD

### Player Reference

```pike
object me = this_player();
string userid = me->name;
string name_cn = me->query_name_cn();
```

### Temporary Variables

```pike
// Set
me["/tmp/last_action"] = "look";

// Get
string action = me["/tmp/last_action"];
```

### Permanent Variables

```pike
// Set
me["/plus/total_kills"] = 100;

// Get
int kills = me["/plus/total_kills"];
```

## Best Practices

1. **Declare variables at function start** - Avoid duplicate declarations
2. **Use `functionp()` before calling** - Check if method exists
3. **Use `objectp()` for object checks** - Proper type checking
4. **Initialize mappings and arrays** - `([])` and `({})`
5. **Use `mixed` for unknown types** - But prefer specific types when possible
6. **Always return 1 from commands** - Command handlers must return 1
7. **Use `sscanf` for parsing** - Efficient string pattern matching
8. **Check sscanf return value** - Returns count of matched items, not boolean

## Common Gotchas

```pike
// 1. random() takes only ONE argument
int r = random(100);      // 0-99
int r2 = random(9000) + 1000;  // 1000-9999 (NOT random(1000, 9999))

// 2. sprintf placeholder count must match argument count
sprintf("<a href='%s?cmd=%s'>%s</a>", url, cmd, label);  // 3 placeholders, 3 args ✅

// 3. Delete mapping keys - Use m_delete NOT map_delete
m_delete(m, "key");  // ✅ CORRECT
map_delete(m, "key"); // ❌ WRONG - Undefined identifier

// 4. File operations - Use Stdio module
if(Stdio.isfile(path)) { }  // ✅ CORRECT
if(file_exists(path)) { }   // ❌ WRONG - Undefined function
```

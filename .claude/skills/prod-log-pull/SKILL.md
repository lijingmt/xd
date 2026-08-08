---
name: prod-log-pull
description: 从生产服务器 192.168.1.205 拉取 Xiand 游戏日志做诊断。当用户说"抓生产日志"、"看 205 的日志"、"线上错误"、"玩家报 bug 但本地复现不了"、"线上出错了"等时使用。覆盖 SSH 访问、关键日志路径、常见错误模式、隐私/安全注意事项。
version: 1.0.0
---

# 生产日志拉取与分析

## 触发场景

- 玩家报 bug，本地复现不了 → 抓生产日志找根因
- 用户说"查下生产"、"线上日志"、"205 的日志"、"production"
- TestUnit 通过但线上仍然坏 → 看真实玩家路径
- 修复后想让用户在生产上验证

## SSH 访问

```bash
ssh root@192.168.1.205 "<command>"
```

- 已配置 SSH key（本机可直接连，不需密码）
- 用户提到的密码 `Palm34cc1122` 仅作备用，正常无需
- 远程仓库：`/home/games/git/xd`（与 GitHub origin 同步，docker 镜像就是从这里构建）
- 加 `-c safe.directory=/home/games/git/xd` 才能 git 操作（dubious ownership 守护）

## 关键日志路径

| 日志 | 路径 | 用途 |
|------|------|------|
| 游戏主日志 | `/usr/local/games/allxd/log/xd01-02/stderr.13800` | Pike 编译错误、运行时异常、heart_beat 报错。**最常分析**。文件巨大（GB 级），用 `tail` / `grep` 不要 `cat` |
| HTTP API | `/usr/local/games/allxd/log/xd01-02/http_api*.log` | 接口异常、超时、401/409 |
| 账号登录 | `/usr/local/games/allxd/log/xd01-02/account_character_login.log` | 多角色登录失败、强制登出 |
| 账号仓库 | `/usr/local/games/allxd/log/xd01-02/account_storage.log` | 跨角色转移失败 |
| 账号钱包 | `/usr/local/games/allxd/log/xd01-02/account_wallet.log` | 共享充值消费异常 |
| 自动挂机 | `/usr/local/games/allxd/log/xd01-02/autofight*.log` | autofight_storage / autofight_sell / autofight_material_sell |
| 限时活动 | `/usr/local/games/allxd/log/xd01-02/timed_event*.log` | 集结、九曜、天衡 |
| 拍卖 | `/usr/local/games/allxd/log/xd01-02/auctiond*.log` | 拍卖交易 |
| 制造/锻造 | `/usr/local/games/allxd/log/xd01-02/artisan.log` | 锻造失败 |
| 玩家礼物 | `/usr/local/games/allxd/log/xd01-02/get_gift.log` | 礼物领取（看 gift_take.pike） |

## 抓日志的标准姿势

**永远先 `tail` 再 `grep`，不要 `cat` 整个文件**：

```bash
# 抓最近 N 行到本地分析
ssh root@192.168.1.205 "tail -5000 /usr/local/games/allxd/log/xd01-02/stderr.13800" > /tmp/prod_stderr.log
```

```bash
# 直接 grep 计数
ssh root@192.168.1.205 "grep -c 'fight.pike:3804' /usr/local/games/allxd/log/xd01-02/stderr.13800"
```

```bash
# 找某个玩家 / 房间 / 技能 相关的行
ssh root@192.168.1.205 "grep -i 'jinaodao/feishagu\|xd01xxxxx' /usr/local/games/allxd/log/xd01-02/stderr.13800 | tail -50"
```

## 分析 stderr.13800 的常见错误模式

### 1. Pike 编译错误（程序性，致命）

```
ERROR: *<错误类型>.
<文件>:<行号>: <调用栈>
```

抓所有 ERROR 行：

```bash
grep -B1 -A6 "^ERROR:" /tmp/prod_stderr.log | head -100
```

按文件:行号 聚类找高频 bug：

```bash
grep -E "^lowlib/|^gamelib/" /tmp/prod_stderr.log | grep -oE "[a-z_/]+\.pike:[0-9]+" | sort | uniq -c | sort -rn | head -20
```

### 2. 调用栈读懂

Pike backtrace 输出顺序：**最近调用在前**，最旧的在最后。例如：

```
ERROR: *Indexing the NULL value with "name".
lowlib/wapmud2/inherit/feature/fight.pike:3804: user()->heart_beat_action()    ← 报错点
lowlib/mudlib/inherit/feature/heartbeat.pike:26:    user()->heart_beat()       ← 调用者
lowlib/efuns.pike:1502:                              heart_beat_slice()       ← 再上一层
-:1: Pike.Backend(0)->`()(3600.0)                                            ← Pike 主循环
```

读法：从下往上看调用链，从上往上看具体触发点。

### 3. 常见高危信号

- `Indexing the NULL value with "X"` — 对 NULL 对象取字段（`obj->field` 但 obj 是 0）
- `Bad argument N to <func>` — 调用 builtin 函数时参数类型错（NULL、空字符串等）
- `Attempt to call the NULL-value` — 把 0 当函数调用（`enemy->method()` 但 enemy 已析构）
- `Calling undefined function` — 调用了不存在的方法
- `divide by zero` — 除零
- `Too few arguments` — 参数不够
- `Cannot index string` — 把字符串当数组下标

## 隐私 & 安全

**绝不**抓取或粘帖：

- `account_character_login.log` 里包含的真实玩家密码 / txd
- `account_wallet.log` 里的充值流水（含订单号、第三方支付 ID）
- 任何玩家的手机号、安全码、邮箱、实名信息（搜索 `mobile` / `phone` / `email` / `id_card`）
- `data_xiand/u/<分区>/<账号>.o` 玩家存档文件

**可以**抓取和讨论：

- 错误栈、文件路径、行号
- 房间名、NPC 名、技能 ID（不含玩家真实身份）
- 模式 / 计数（"X 错误出现 N 次"）

## 工作流

1. **明确问题**：玩家报什么 bug？发生在哪个区、哪个等级、哪个角色？
2. **定位日志**：根据问题类型选 stderr / autofight / account / timed_event
3. **拉到本地**：`ssh ... "tail -N ..." > /tmp/xxx.log`，避免多次往返
4. **grep 聚类**：按文件:行号 找高频错误
5. **回本地复现**：根据栈路径，读源码确认 bug
6. **修 + TestUnit**：本地修完跑 ./restart.sh，确保 64/0/4
7. **生产部署**：用户决策何时部署；不要自动 deploy 到 205
8. **部署后复测**：部署完后抓同一段日志，确认错误消失

## 部署到生产

**生产是 docker**，部署流程见 `docker-deployment.md` skill。本 skill 只负责"看日志"。

- 部署是用户的动作，Claude 不要主动 ssh 部署
- 部署完后可以再抓日志验证

## 已知日志噪声（不需要修，专注真 bug）

- `lowlib/driver.pike:135: Warning: Using a deprecated value.` — Pike 9 兼容警告
- `lowlib/driver.pike:191: Warning: Using a deprecated value.` — 同上
- `http_api_daemon.pike:NNNN: Using a deprecated value.` — 同上
- TestUnit 输出（在 stderr 里）：`[TESTUNITD] PASS test_xxx.pike` 等是正常启动日志

## 相关 skill

- `common-issues` — 已知的常见问题和解决方案
- `docker-deployment` — 部署流程
- `autofight-system` — 挂机系统内部

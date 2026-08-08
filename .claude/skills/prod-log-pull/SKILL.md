---
name: prod-log-pull
description: 从 192.168.1.205 安全抓取、脱敏、聚类并对比 Xiand 生产日志。用户提到生产日志、205、线上错误、玩家路径无法本地复现、挂机/HTTP/多人物线上异常或修复后日志验证时使用。
---

# Xiand 生产日志安全取证

本 skill 只授权只读诊断，不授权在 205 部署、重启、编辑文件或执行 Git
写操作。生产部署必须由用户另行明确决定。

## 固定信息

- SSH：`root@192.168.1.205`，使用本机已有 SSH key；skill、命令和日志中
  禁止保存密码。
- 生产仓库：`/home/games/git/xd`。
- Git 只读查询需加：`-c safe.directory=/home/games/git/xd`。
- 日志根目录：`/usr/local/games/allxd/log/xd01-02/`。

## 工作流

1. 先查生产 commit：

   ```bash
   ssh root@192.168.1.205 "cd /home/games/git/xd && git -c safe.directory=/home/games/git/xd log --oneline -1"
   ```

2. 永远先 `tail`，不要 `cat` 大日志。优先使用 Codex skill 中的脱敏脚本：

   ```bash
   /Users/jingli/.codex/skills/prod-log-pull/scripts/pull_sanitized_log.sh 12000 stderr.13800
   ```

3. 只分析脚本输出的 mode-0600 脱敏文件。`stderr.13800` 的 HTTP 栈也可能
   包含 TXD、密码、账号和 socket 标签，不能直接复制原始栈。
4. 先按 `ERROR:` 和 `文件.pike:行号` 聚类，再查看少量上下文。
5. 回本地源码核对，并依据生产 commit 的祖先关系区分：
   - 生产尚未部署的已知修复；
   - 当前 main 仍存在的新问题；
   - 已知无害警告。
6. 只报告脱敏后的计数、文件、函数和原因。完成后删除本地临时日志。

## 日志选择

- `stderr.13800`：Pike 编译/运行时/heartbeat，最常用，必须限行脱敏。
- `account_character_login`：多人物登录、强制登出，账号敏感，通用脚本明确拒绝。
- `account_storage`：跨人物仓库，账号和物品敏感，通用脚本明确拒绝。
- `account_wallet`：订单/支付敏感，通用脚本明确拒绝。
- `autofight_storage` / `autofight_sell`：挂机仓储与出售。
- `timed_event.log`：限时活动状态。
- `bossdrop_error`：Boss 掉落加载错误。
- `compile_errors`：体积较大，只取 bounded tail。

## 安全红线

- 不读取 `data_xiand/u/` 玩家存档。
- 账号、跨人物仓库与支付事故需另行授权，只允许专门审查后的聚合流程。
- 不输出 TXD、密码、authorization、手机号、邮箱、实名、订单号、支付 ID。
- 不把 SSH 密码写进 skill、源码、命令、聊天或 shell history。
- 不因看见旧行号就断言新回归；先对比生产 commit。
- 不自动部署到 205。

本地修复必须先完成前端测试/构建、完整 Pike 重启、内部 TestUnit
`failed=0` 和新鲜本地日志检查，最后才抓生产日志作对比。

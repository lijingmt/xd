# 历史异常玉石一次性回收

本机制只处理严格早于 `2026-08-01` 创建的旧人物账号。每个 Worker 会在启动时
读取历史玉石日志并建立只读证据索引；人物登录时用实时余额完成一次性审计，
不需要管理员逐个维护账号白名单，也不需要部署候选清单。

## 审计公式

所有玉石先折算成碎玉：

```text
充值保留额度 = all_fee × 10
无法解释的现存玉 = max(0, 当前人物背包和人物仓库实体玉 - 充值保留额度)
一次性回收额 = min(精确刷玉证据额, 无法解释的现存玉, 当前人物实体玉, 2000万)
```

旧拆玉代码在“2块高阶玉打碎为20块低阶玉”时，日志记录扣2块、实际只扣1块，
因此每一条成功旧日志都能证明精确异常铸造额。结构化转换日志也只在明确成功且
目标价值大于来源价值时计入证据。没有精确异常铸造事件时，即使余额很高、拆合
频繁或同秒操作也不会回收。

旧版 `all_fee` 曾按递归面额重复累计；统一乘以 10 会多给玩家保留额度，
只会少回收，不会扩大回收额。共享充值钱包始终不参与扣除。

## 执行保护

1. 自动索引只接受固定格式的历史拆玉漏洞日志和价值增发的成功结构化日志；文件
   必须是普通文件，并受单文件、总字节数和事件数上限保护。
2. 登录事务使用同一份实时背包、人物仓库和 `all_fee` 快照。若数据在执行前
   变化会拒绝本次事务；无法解释额为零则永久按零结案，之后不追缴。
3. 每个人物既保存终身结案凭据，也在多 Worker 共享数据目录中原子创建永久
   claim；旧 Worker 即使持有过期人物对象也不能重复执行。进程在占位后崩溃
   时宁可本次免收，也不会删除 claim 后重试。
4. 已消费的部分不形成欠款，后续充值、奖励和交易所得不会再次扣除。
5. 单个人物单次回收硬上限为 2000 万碎玉；高于上限的证据不会扩大扣除。
6. 扣除、人物存档、精确回滚和审计日志均有独立校验；模块异常不会阻断登录。
7. 若共享仓库仍记录该人物存入的玉，自动事务会延期并写审计日志，避免跨人物、
   跨 Worker 的非原子误扣；隔离共享来源后，下次登录可重新审计。

## 可选离线复核

运行时不依赖离线清单。若管理员需要上线前复核统计，可先生成证据候选，再读取
候选的背包、人物仓库、充值钱包和共享仓库快照；脚本只输出聚合统计，账号明细
只应存在权限 `0600` 的临时文件中：

```bash
python3 scripts/audit_illicit_jade.py \
  --log-root /restricted/log/xd01-02 \
  --registration-root /restricted/gamelib/data/uniq_user \
  --created-before 2026-08-01 \
  --output /restricted/security/jade-candidates.json

python3 scripts/snapshot_illicit_jade_candidates.py \
  --data-root /restricted/data_xiand \
  --candidate-manifest /restricted/security/jade-candidates.json \
  --output /restricted/security/jade-financial-snapshot.json
```

若共享仓库中仍有来自目标人物的玉，案件会延期，不会自动执行。玉石
历史上允许8级以上人物赠送、交易和拍卖，因此已经转给其他人物的部分不会追缴，
也不会向接收者连坐回收。最终清单由下列命令生成；所有符合条件的案件默认自动
批准：

```bash
python3 scripts/audit_illicit_jade.py \
  --log-root /restricted/log/xd01-02 \
  --registration-root /restricted/data_xiand/new_users \
  --created-before 2026-08-01 \
  --financial-snapshot /restricted/security/jade-financial-snapshot.json \
  --output /restricted/security/illicit_jade_recovery.json
```

如只想查看最终候选而不启用执行，可追加 `--review-only`。高余额、操作频率、
同秒拆合玉或账本不完整的单纯 `all_fee` 差额仍然只进入 `review_only`，不会因为
自动批准模式而执行。

财务快照必须使用权限 `0600` 保存，结构如下。`captured_at` 使用 Unix 时间；
`legal_ledger_complete` 只有在旧大额充值、充值赠送、奖励、交易、赠送、宝箱、
家园出售和管理员补发都已核对后才可设为 `true`。

```json
{
  "schema_version": 1,
  "captured_at": 1786636400,
  "accounts": {
    "review_account": {
      "current_physical_suiyu": 12000,
      "current_personal_storage_suiyu": 0,
      "current_shared_source_suiyu": 0,
      "current_wallet_suiyu": 0,
      "all_fee": 500,
      "legal_non_all_fee_suiyu": 1000,
      "legal_ledger_complete": false
    }
  }
}
```

`data_xiand/security/illicit_jade_recovery.json` 仅保留为旧部署的兼容通道，
不是自动登录审计的前置条件，也不得把真实账号清单提交到 Git。若仍部署该文件，
运行时会继续严格校验其结构、证据摘要、快照时效和实时余额。

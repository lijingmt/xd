# 历史异常玉石一次性回收

本机制只处理严格早于 `2026-08-01` 创建的旧人物账号。默认配置为
`enabled=false`、`state=review`，扫描程序不会修改人物档案，运行时也不会
读取未逐条批准的账号。

## 审计公式

所有玉石先折算成碎玉：

```text
充值保留额度 = all_fee × 10
无法解释的现存玉 = max(0, 当前人物实体玉 - 充值保留额度 - 未体现在 all_fee 中的已核实合法玉)
一次性回收额 = min(精确刷玉证据额, 无法解释的现存玉)
```

旧拆玉代码在“2块高阶玉打碎为20块低阶玉”时，日志记录扣2块、实际只扣1块，
因此每一条成功旧日志都能证明精确异常铸造额。没有精确刷玉事件时，只有在未记入
`all_fee` 的合法玉账本被人工确认完整后，才允许把
“无法解释的现存玉”作为候选。账本不完整、高余额、频繁拆合玉、同秒操作
都只能进入 `review_only`，不能自动执行。

旧版 `all_fee` 曾按递归面额重复累计；统一乘以 10 会多给玩家保留额度，
只会少回收，不会扩大回收额。共享充值钱包始终不参与扣除。

## 执行保护

1. 审计清单生成后仍是关闭状态，每个候选也都是 `approved=false`。
2. 余额快照同时覆盖背包和人物仓库，只在一小时内有效；人物实体玉、共享钱包或
   `all_fee` 任一变化，
   本次按零回收结案，之后不追缴。
3. 每个人物既保存终身结案凭据，也在多 Worker 共享数据目录中原子创建永久
   claim；旧 Worker 即使持有过期人物对象也不能重复执行。进程在占位后崩溃
   时宁可本次免收，也不会删除 claim 后重试。
4. 已消费的部分不形成欠款，后续充值、奖励和交易所得不会再次扣除。
5. 单次超过 2000 万碎玉的结果只进入人工复核，运行时拒绝执行。
6. 扣除、人物存档、精确回滚和审计日志均有独立校验；模块异常不会阻断登录。

## 离线扫描

先生成证据候选，再读取这些候选的背包、人物仓库、充值钱包和共享仓库快照；
脚本只输出聚合统计，账号明细只存在权限 `0600` 的临时文件中：

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

若共享仓库中仍有来自目标人物的玉，案件只进入人工复核，不会自动执行。
最终清单由下列命令生成：

```bash
python3 scripts/audit_illicit_jade.py \
  --log-root /restricted/log/xd01-02 \
  --registration-root /restricted/data_xiand/new_users \
  --created-before 2026-08-01 \
  --financial-snapshot /restricted/security/jade-financial-snapshot.json \
  --output /restricted/security/illicit_jade_recovery.json
```

对已经确认的旧拆玉精确证据自动批准时，追加
`--approve-exact-evidence`。该开关只批准
`legacy_split_remainder_bug`，不会批准高余额、操作频率或单纯 `all_fee` 差额。

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

未使用自动批准开关时，只有复核完成后才能手工批准。清单必须放在
运行时数据目录 `data_xiand/security/illicit_jade_recovery.json`，不得提交真实
账号清单到 Git。

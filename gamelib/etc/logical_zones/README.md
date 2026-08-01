# 逻辑分区配置

每个启用的逻辑区对应一个四位区号 `.conf` 文件，例如 `xd06.conf`。
守护进程每 5 秒读取一次，增加、修改或删除配置都不需要重启 MUD。

复制 `zone.conf.example` 为 `xd06.conf`，并让文件名与 `zone_id` 一致。

- `isolation=1`：玩家只可看见、PK、组队和联系本区玩家。
- `isolation=0`：玩家可与相同 `cluster` 的其他非隔离区互通，即在线合区。
- `enabled=0`：不展示该区，也禁止新注册和登录。
- `registration_open=0`：保留老玩家登录，但关闭新注册。
- `open_at`：Unix 时间戳；为 0 表示立即开放。
- `schema_version`：当前固定为 `1`，防止未来格式变更被旧程序误读。
- `revision`：人工递增的配置版本，便于审计和确认回滚是否生效。
- `sort`：登录界面的显示顺序。
- `notes`：不超过 256 字符的运维备注。

`schema_version`、`revision`、`zone_id`、`name`、四个开关字段和 `cluster`
必须显式填写，避免漏写开关时意外开放新区。`cluster` 只接受小写字母、数字、
下划线和连字符。

任何一份 `.conf` 非法时，整批修改均不会生效，服务继续使用上一份有效配置。
最多允许 99 个 `.conf`，每个文件最多 8192 字节。

建议使用 `scripts/logical-zone-admin.sh` 管理配置。`create` 默认关闭登录和注册，
`set/isolate/merge/open/close` 都会先生成带 revision 的备份，再原子替换配置文件。
游戏内管理员也可进入 `gamelib/d/manager_room`，点击“逻辑新区管理”；后台使用
与 daemon 相同的 parser，并在完整快照加载失败时自动恢复 `.bak`。

## Docker 首次部署

`restart-docker.sh` 会把 `deploy/logical_zones/` 中的首装种子复制到
`/usr/local/games/allxd/<GAME_AREA>/etc/logical_zones/`。该复制只在目标目录完全没有
`.conf` 时执行；一旦已有线上配置，重建镜像和重启容器都只读取、不覆盖。

需要使用另一套首装配置时，可设置绝对路径环境变量
`XIAND_LOGICAL_ZONE_SEED_DIR=/path/to/seed`。镜像构建会排除活动目录中的
`gamelib/etc/logical_zones/xd*.conf`，避免开发或生产配置被意外烘焙进镜像。

## 可逆操作

- 开独立新区：新增配置，设置 `isolation=1`。
- 关注册但保留老玩家：设置 `registration_open=0`。
- 在线合区：相关配置都设为 `isolation=0` 且使用同一个 `cluster`。
- 恢复隔离：把各区改回 `isolation=1`；系统会清理跨区战斗、队伍和跟随。
- 临时停区：设置 `enabled=0`；恢复为 `1` 后账号数据仍在原位置，无需迁移。

每次操作先保存上一版文件并递增 `revision`。账号区号从不改变，所以合区和拆区
只切换交互策略，不改玩家存档，回滚不会产生账号搬迁。

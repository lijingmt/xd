# 同进程逻辑分区设计与运维手册

## 目标

一套 Pike MUD 进程承载多个逻辑区。新区账号仍使用原来的四位区号前缀，
不复制玩家存档、不改地图路径、不重启服务。独立区之间的玩家在视觉和玩家交互上
彼此不存在；需要合区时只改变配置，未来也可以恢复隔离。

这是一层 server-authoritative 的逻辑 realm/tenant 分区，不是前端隐藏。
所有决定都由后端根据账号区号执行，伪造按钮、命令或 HTTP 参数也不能绕过。

## 代码结构

```text
gamelib/single/daemons/logical_zoned.pike        # 生命周期、原子快照、稳定门面
└── _logical_zone_mod/
    ├── config.pike                              # schema 与公共常量
    ├── config_loader.pike                       # 解析、校验、候选快照
    ├── identity.pike                            # 玩家/召唤兽/掉落/NPC 的归属
    ├── policy.pike                              # 可见、交互、登录与注册策略
    ├── capabilities.pike                        # 领域能力矩阵与统一策略网关
    └── reconciliation.pike                      # 热切分后的关系清理

gamelib/etc/logical_zones/                       # 唯一运行期配置入口
scripts/logical-zone-admin.sh                    # 原子写入、备份、开区/合区工具
test_unit/test_logical_zone_isolation.pike       # 策略和接线回归
test_unit/test_home_logical_zone.pike             # 多维家园和旧房契兼容回归

gamelib/single/daemons/homed.pike                 # 家园事务门面和内存状态
└── _home_mod/
    ├── logical_zone.pike                         # 固定产权区索引、路径解析和审计
    └── persistence.pike                          # 三份家园关联数据原子快照与回滚
```

业务代码不得自行解析区号或读取 `.conf`。新增代码优先调用带领域名的能力网关：

- `LOGICALZONED->can_action("combat", actor, target)`：对象级领域判断。
- `LOGICALZONED->can_user_action("trade", actor_id, target_id)`：账号级领域判断。
- `can_interact/can_user_interact`：旧代码兼容入口，等价于 `generic` 能力。
- `LOGICALZONED->is_visible(viewer, target)`：显示判断。
- `LOGICALZONED->registration_allowed(zone_id)`：注册入口。
- `LOGICALZONED->login_allowed(user_id)`：登录入口。

这让配置格式未来可以升级，而战斗、组队、拍卖等业务入口不需要跟着重写。

## 身份和策略模型

玩家账号的前四位是不可变身份，例如 `xd06alice` 属于 `xd06`。

- `isolation=1`：交互组为 `zone:xd06`，只和同区账号匹配。
- `isolation=0`：交互组为 `cluster:<cluster>`，相同 cluster 的区互通。
- 配置不存在、关闭或区号非法：失败关闭，不会意外进入 `main` 共享组。
- 无四位区号的历史/测试对象保留 `legacy:main` 兼容行为。
- 固定跨区管理员 `jinghaha`、`mumu215`（含合法区号前缀）属于控制面。
  管理员作为主动方时可跨区查看、救援和审计；普通玩家不能借“目标是管理员”
  穿透可见性、战斗、交易或榜单。只有私聊和邮件允许跨区联系管理员客服。

召唤兽继承主人区；房间掉落物使用独立的 `item_logical_zone_owner` 永久继承
击杀者区，不受 120 秒拾取保护过期影响；普通怪物开战后
临时继承首攻玩家区。这样跨区玩家既看不到战斗对象，也不能争抢同一交战目标。
未交战的公共 NPC、地图模板和刷新系统仍由同一进程共享，这是逻辑分区节省资源的
关键；若未来要求每区拥有完全独立的 NPC 数量和资源产能，应升级为“按区克隆房间实例”，
不能用前端隐藏冒充独立世界。

## 隔离边界

| 边界 | 独立区行为 | 合区行为 |
| --- | --- | --- |
| 房间玩家、召唤兽、移动消息 | 互不可见 | 同 cluster 可见 |
| 点击人物、装备、家园 | 不可查询 | 可查询 |
| PK、助战、跟随、御剑 | 后端拒绝 | 可用 |
| 组队、队伍聊天、战利品分配 | 后端拒绝并清理旧关系 | 可用 |
| 私聊、邮件、好友、关注 | 不展示且不可发送 | 可用 |
| 公共聊天、广播 | 玩家消息按区过滤 | 同 cluster 可见 |
| 交易、赠送、拍卖 | 买卖双方和列表均过滤 | 可用 |
| 帮派、申请、帮主转让 | 列表和成员按区过滤 | 可用 |
| 排行榜 | 只显示当前交互组 | 合并展示 |
| 掉落物 | 永久按归属区过滤 | 同 cluster 可见 |
| 家园同号房 | 各区独立产权且互不可见 | 按“产权区街区”并列显示，不覆盖 |
| 家园作物、店铺、访客 | 只访问本交互组数据 | 同 cluster 可访问，产权仍归原区 |
| 登录、注册、区列表 | 由区配置决定 | 由区配置决定 |

固定跨区管理员仍可看见并处理各区账号，这是运维控制面，不属于普通玩家边界。

## 配置格式

每个显式逻辑区一个文件，文件名必须与 `zone_id` 相同：

```ini
schema_version=1
revision=1
zone_id=xd06
name=仙道六区
enabled=1
registration_open=1
login_open=1
isolation=1
cluster=main
sort=6
open_at=0
notes=2026-08-01 首次开放
```

字段说明：

- `schema_version`：当前只接受 `1`，避免新旧程序误读。
- `revision`：每次运维改动人工递增，用于审计。
- `enabled`：是否展示和接受登录；改为 0 不强踢现有连接。
- `registration_open`：是否允许创建新账号。
- `login_open`：是否允许已有账号建立新登录连接。
- `isolation`：1 为独立区；0 为 cluster 合区。
- `cluster`：仅在 `isolation=0` 时决定哪些区互通。
- `open_at`：Unix 秒时间戳，0 为立即开放。
- `sort`：登录区列表顺序。
- `notes`：运维说明，不参与策略。

`schema_version`、`revision`、`zone_id`、`name`、四个开关字段和 `cluster`
都是必填项；缺少任一项会拒绝整份候选快照。`cluster` 只接受小写字母、数字、
下划线和连字符，避免不可见字符造成误合区。

`GAME_AREA=xd01-02` 会自动生成 `xd01`、`xd02` 的物理默认配置；显式 `.conf`
可以覆盖它们。未知四位区号不能注册或登录。

Docker 首次部署由 `restart-docker.sh` 将 `deploy/logical_zones/` 的种子配置复制到
宿主机 `/usr/local/games/allxd/<GAME_AREA>/etc/logical_zones/`。仅当目标没有任何
`.conf` 时才初始化；后续镜像升级、容器重建不会覆盖管理员已经修改的配置。
可通过 `XIAND_LOGICAL_ZONE_SEED_DIR` 显式选择另一套绝对路径种子目录。

## 热加载和失败语义

daemon 每 5 秒构建一次候选快照。最多接受 99 个 `.conf`，单文件最多 8192 字节，
防止配置目录误放大文件造成周期性资源耗尽：

1. 读取并按文件名排序全部 `.conf`。
2. 校验文件名、区号、重复字段、类型、schema、长度和开关值。
3. 任一文件失败，拒绝整批候选，继续使用上一代有效快照。
4. 全部有效后，在互斥锁内一次性替换快照并递增 `generation`。
5. 异步清理已经存在的跨区战斗、组队和跟随关系。

快照发布后不再原地修改。房间渲染、战斗心跳和 HTTP 轮询走只读引用，不在每次
`can_interact` 时获取 mutex；只有热加载写入和状态统计使用锁。这是 read-copy-update
模式，避免多线程前端请求在最热的可见性路径上互相阻塞。

`GET /api/partitions` 只返回登录所需字段（包括登录/注册开放状态）和
`generation / last_reload / healthy / zone_count` 健康摘要，不公开 cluster、revision、
配置文件名或错误详情。完整 `last_error` 只通过服务端日志和内部 daemon 状态查看。
非法编辑不会造成半合区；修复后错误状态自动清除。
公开分区按配置中的 `sort` 从大到小排列，同值时按区号从大到小排列；Vue 客户端还会
做一次相同的防御性排序。因此最新、最大的区排在列表最前；尚未开放的区会显示为维护
或暂停注册，默认选择会跳过它们。已经保存且仍可登录的玩家分区选择会被保留。

## 可逆运维流程

管理员打开“游戏内部管理接口平台”（`game_deal`）后可点击“逻辑新区管理”；
`gamelib/d/manager_room` 也保留同一入口。后台支持安全创建新区、
开放/关闭/下架、修改区名/备注/定时开放时间、隔离/恢复合区、多区合并和上一版回滚。只有
`MANAGERD->checkpower(id)=="admin"` 可调用写接口；每次修改都会：

1. 从当前不可变快照复制候选配置并递增 revision。
2. 用与热加载器相同的 parser 校验候选。
3. 保存 `.bak`，写临时文件后通过 rename 原子替换。
4. 强制构建整份快照；失败则恢复 `.bak` 并再次加载。
5. 写入 `log/logical_zone_admin.log` 操作审计。

后台合区会先把所有目标区设为隔离，再统一 cluster，最后逐区解除隔离；中间状态
只会短暂减少互通，不会意外连到错误的区。并发管理员修改使用 revision 乐观校验和
独立管理锁，旧页面提交会提示刷新，不会覆盖较新的配置。

单区详情根据当前状态显示互斥操作：合区状态显示“设为独立隔离”，隔离状态显示
“恢复合区（当前 cluster）”。两个方向都需要二次确认；恢复合区只解除隔离、不改变
原 cluster，需要更换分组时使用“合并多个区”。

### 开独立新区

1. 执行 `scripts/logical-zone-admin.sh create xd06 仙道六区 6`。
2. 新配置默认 `isolation=1` 且关闭登录、注册，先检查服务端健康日志。
3. 执行 `scripts/logical-zone-admin.sh open xd06`，5 秒内开放，无需重启。

### 在线合区

假设合并 `xd06` 与 `xd07`：

1. 执行 `scripts/logical-zone-admin.sh merge season_2026_08 xd06 xd07`。
2. 工具会逐文件备份、递增 revision，并先写 cluster、最后解除 isolation。
3. 第一份先落地时仍与另一独立区不互通，属于安全的失败关闭中间态。
4. 第二份落地后两区自动互通，账号 ID 和存档位置不变。

### 恢复隔离（拆区/回滚）

1. 恢复保存的配置，或把两份都改回 `isolation=1` 并递增 revision。
2. 第一份生效即停止跨区新交互。
3. daemon 自动结束跨区战斗并清理队伍、邀请和跟随。
4. 拍卖历史竞价若在结算时已跨区，会走取消/退款，不把物品交给错误区。

因为从未迁移账号或改写玩家数据，这个回滚是策略回滚，不是数据回滚。

## 多维家园与老数据兼容

家园不能继续使用单一地图房号作为产权唯一键，否则两个独立区分别购买同一个
“1 号房”后会在合区时相互覆盖。现在使用永久二维产权键：

```text
产权唯一键 = 房主账号固定区号 @ 原地图房号
示例：xd01@xd/qianxuehu/qianxuemen/lei/1
      xd03@xd/qianxuehu/qianxuemen/lei/1
```

这两个家园共享地图模板和位置名称，但房主、房间对象、作物、功能房、店铺、访客和
房契均独立。合区列表会显示为“XD01街区·某某之家”和“XD03街区·某某之家”；
玩家通过带产权区的新链接进入准确维度。再次隔离只隐藏另一产权区，不迁移或删除房产。

兼容策略如下：

1. `detail_home` 中已有的旧 `homeId` 和玩家存档中的旧 `home_path` 原样保留，不执行
   批量改写。启动时根据房主账号前缀在内存重建固定产权区索引。
2. 旧链接优先解析到访问者自己的原生产权区；没有本区房产且该房号只有一个候选时，
   可兼容解析。若合区后同号房有多个候选且旧链接无法唯一确定，则失败关闭，玩家需从
   带“街区”标签的新列表进入，绝不随机串房。
3. 新购房写入带区号的稳定引用。购买列表只检查玩家自己的固定产权区，所以独立区可
   购买相同房号；合区也不能抢占或改写另一产权区的房契。
4. `map_home` 继续保存原地图房号供老读取器获得地段、公寓元数据；真正产权以
   `detail_home` 和内存二维索引为准。因此旧房契仍可进入、种养、经营和变卖。
5. 推荐店铺、销量排行、访问、敲门和最终购买都通过 `home` 能力过滤；列表隐藏与最终
   写操作同时校验，不能靠伪造客户端命令跨区。

购房和变卖使用家园状态 mutex。购房在锁内重新检查“玩家无房”和“本产权区房号空闲”，
扣款后同时写入房契与索引；三份关联文件先写临时文件并校验，备份后依次原子替换，
`detail_home` 最后作为产权提交点。提交失败会恢复内存状态并退还玉石、金钱。变卖价格
完全由服务端房契重算，忽略客户端链接中的金额，保存失败则保留原房契。

从合区切回隔离时，配置热加载会扫描在线玩家：若仍停留在现在不可访问的跨区家园，
先从该家园的 `userIn` 记录移除，再送回凝歌殿。离线玩家登录恢复时也重新检查 `home`
能力，不会利用旧 `last_pos` 重入跨区房间。

### 维护或关闭新区

- 只关注册：`registration_open=0`。
- 阻止新连接但保留现有在线会话：`login_open=0`。
- 从登录列表移除并阻止新登录：`enabled=0`。
- 删除显式新区配置：该区变为未知区并失败关闭；建议先关注册和登录再删除。

## 部署

`restart-docker.sh` 会把逻辑分区目录补到宿主机挂载的 `etc` 中，使用
`rsync --ignore-existing`，因此镜像升级不会覆盖生产环境已经编辑的 `.conf`。
容器挂载后直接读取这些文件，运行期改动不依赖重建镜像。

部署脚本把 `etc` 目录设为目录 `755`、文件 `644`，不再世界可写。若在挂载目录
管理生产配置，设置 `XIAND_LOGICAL_ZONE_DIR=/usr/local/games/allxd/xd01/etc/logical_zones`
后运行管理脚本。旧 `login_fee` 维护入口还要求至少 24 字符的
`XIAND_MAINTENANCE_TOKEN`，未配置时默认拒绝，不再提供匿名维护登录。

配置文件应纳入生产配置备份；代码仓库只保留说明和示例，不默认提交一个真实开放区，
避免部署后意外开放注册。

## 测试与审计

- `test_unit/test_logical_zone_isolation.pike` 测试配置拒绝、隔离/合并/恢复、
  未知区失败关闭、业务接线和模块结构。
- `test_unit/test_home_logical_zone.pike` 测试现有老房契索引、新旧引用解析、同号多维键、
  购买事务、原子存档、拆区回收、商店过滤和全部变更文件的真实 Pike 编译。
- 每次 Pike 改动运行 `./scripts/restart_with_testunit.sh`，要求 TestUnit 零失败。
- 检查 `log/stderr.13800` 中 `[LOGICALZONED]` 和 `[TESTUNITD] COMPLETE`。
- 新增任何跨玩家功能时，同时检查“列表读取”和“最终写操作”，两处都必须调用策略门。

## 业界参照

这个设计采用成熟游戏中常见的“逻辑世界身份 + 受控互通”思路，但针对单进程 MUD
做了轻量化：

- Final Fantasy XIV 保留 Home World/Data Center 身份，并在跨数据中心访问时限制
  部分社交和经济功能：
  https://na.finalfantasyxiv.com/lodestone/playguide/contentsguide/datacentertravel/
- Guild Wars 2 的 megaserver 把玩家放入共享地图实例，同时用世界/队伍/公会等规则
  决定匹配和归属：
  https://wiki-en.guildwars2.com/wiki/April_2014_Feature_Pack
- New World 官方持续提供世界合并流程，说明“世界身份”和“物理运行资源”可以分别管理：
  https://www.newworld.com/en-gb/news/articles/road-to-new-world-aeternum-servers
- AWS GameLift 的安全建议要求服务器验证玩家会话身份，不能信任客户端自己声称的区服：
  https://docs.aws.amazon.com/gameliftservers/latest/developerguide/gamelift-howitworks.html

Xiand 的差异是所有隔离策略在同一个 Pike 进程内完成，因此成本低、热切换快；代价是
公共地图/NPC 刷新仍共享，容量上限仍受单进程约束。若未来追求独立资源产能或横向扩容，
应在这个稳定区号/策略接口之下替换成多进程房间实例，而不是让业务代码重新识别区服。

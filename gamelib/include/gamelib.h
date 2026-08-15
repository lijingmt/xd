#ifndef _GAMELIB_H_
#define _GAMELIB_H_

#include <wapmud2/include/wapmud2.h>

#define GAMELIB_USER (ROOT+"/gamelib/clone/user")
#define GAMELIB_INIT (ROOT+"/gamelib/d/init")

#define GAMELIB_NPC ROOT "/gamelib/inherit/npc"
#define GAMELIB_MASTER ROOT "/gamelib/inherit/master"
#define GAMELIB_ROOM ROOT "/gamelib/inherit/room"
#define GAMELIB_ANCIENT_SKILL ROOT "/gamelib/inherit/ancient_hidden_skill.pike"
#define GAMELIB_NEWMOON_SET_SKILL ROOT "/gamelib/inherit/newmoon_set_skill.pike"
#define GAMELIB_ANCIENT_BOOK ROOT "/gamelib/inherit/ancient_hidden_book.pike"
//用户仓库系统
#define GAMELIB_PACKAGED ROOT "/gamelib/inherit/packaged"
//表情系统
//#define CHAT_EMOTED ((object)(ROOT "/gamelib/single/daemons/chatemoted"))
//统计管理模块
#define COUNTD ((object)(ROOT "/gamelib/single/daemons/countd"))
#define CROND ((object)(ROOT "/gamelib/single/daemons/crond"))
//管理后台
#define MANAGERD ((object)(ROOT+"/gamelib/single/daemons/managed"))
//信息记录模块
#define LOG_P ((program)(ROOT "/gamelib/single/daemons/log"))
//物品随即生成模块
#define ITEMSD ((object)(ROOT "/gamelib/single/daemons/itemsd"))
//十职业太古隐藏传承配置、权重与通用成长
#define ANCIENT_SKILLD ((object)(ROOT "/gamelib/single/daemons/ancient_skilld.pike"))
//排行榜系统
#define TOPTEN ((object)(ROOT "/gamelib/single/daemons/topten"))
//任务守护模块
#define TASKD ((object)(ROOT "/gamelib/single/daemons/taskd"))
//新手分步引导守护模块
#define NEWBIED ((object)(ROOT "/gamelib/single/daemons/newbied"))
//每日签到、真实行为目标与活跃度奖励
#define DAILYGOALD ((object)(ROOT "/gamelib/single/daemons/daily_goald.pike"))
//拍卖行守护模块
#define AUCTIOND ((object)(ROOT "/gamelib/single/daemons/auctiond"))
//房间等级守护模块
#define ROOMLEVELD ((object)(ROOT "/gamelib/single/daemons/roomLeveld"))
//采矿守护模块
#define KUANGD ((object)(ROOT "/gamelib/single/daemons/kuangd"))
//锻造守护模块
#define DUANZAOD ((object)(ROOT "/gamelib/single/daemons/duanzaod"))
//炼丹守护模块
#define LIANDAND ((object)(ROOT "/gamelib/single/daemons/liandand"))
//采药守护模块
#define CAOYAOD ((object)(ROOT "/gamelib/single/daemons/caoyaod"))
//熔解守护模块
#define RONGJIED ((object)(ROOT "/gamelib/single/daemons/rongjied"))
//熔炼守护模块
#define RONGLIAND ((object)(ROOT "/gamelib/single/daemons/rongliand"))
//新副业裁缝，制甲材料掉落守护模块
#define VICEDROPD ((object)(ROOT "/gamelib/single/daemons/vicedropd"))
//新副业裁缝，制甲材料怪刷新守护模块
#define VICEFLUSHD ((object)(ROOT "/gamelib/single/daemons/viceflushd"))
//新副业裁缝守护模块
#define CAIFENGD ((object)(ROOT "/gamelib/single/daemons/caifengd"))
//新副业制甲守护模块
#define ZHIJIAD ((object)(ROOT "/gamelib/single/daemons/zhijiad"))
//百工复兴：材料囊、熟练度、大师专精与安全制造事务
#define ARTISAND ((object)(ROOT "/gamelib/single/daemons/artisand.pike"))
//配方守护模块
#define PEIFANGD ((object)(ROOT "/gamelib/single/daemons/peifangd"))
//副本守护模块
#define FBD ((object)(ROOT "/gamelib/single/daemons/fbd"))
//boss掉落守护模块
#define BOSSDROPD ((object)(ROOT "/gamelib/single/daemons/bossdropd"))
//组队管理模块
#define TERMD	((object)(ROOT "/gamelib/single/daemons/termd"))
//阵营级城池守护模块
#define CITYD ((object)(ROOT "/gamelib/single/daemons/cityd"))
//排行榜守护模块
#define PAIHANGD ((object)(ROOT "/gamelib/single/daemons/paihangd"))
//时间模块，以后会做细化和调整
#define TIMESD ((object)(ROOT "/gamelib/single/daemons/timesd"))
//用户登录游戏检查更新模块
#define USERD ((object)(ROOT "/gamelib/single/daemons/userd"))
//用户统计模块
#define USER_COUNTD ((object)(ROOT "/gamelib/single/daemons/user_countd"))
//用户登陆随机提示
#define TIPSD ((object)(ROOT "/gamelib/single/daemons/storyd"))
//用户聊天频道系统
#define CHATROOMD ((object)(ROOT "/gamelib/single/daemons/chatroomd"))
#define CHATROOM2D ((object)(ROOT "/gamelib/single/daemons/chatroom2d"))
#define RACECHATD ((object)(ROOT "/gamelib/single/daemons/racechatd"))
//活动奖励发放模块
#define GIFTD ((object)(ROOT "/gamelib/single/daemons/giftd"))
//玉石系统模块
#define YUSHID ((object)(ROOT "/gamelib/single/daemons/yushid"))
//付费赌装模块
#define DUBOD ((object)(ROOT "/gamelib/single/daemons/dubod"))
//名字管理模块
#define NAMESD ((object)(ROOT "/gamelib/single/daemons/namesd"))
//大额充值数据库相关模块
#define DBD ((object)(ROOT "/gamelib/single/daemons/dbd"))
//大额充值记录文件
#define LOG_BIG_FEE LOG_P(ROOT "/log/fee_log/bigfee")
#define LOG_DBD LOG_P(ROOT "/log/fee_log/dbd")
//用于刷野外boss的守护模块
#define YWBOSS_FLUSHD ((object)(ROOT "/gamelib/single/daemons/yewaiboss_flushd"))
//物品克隆路径
#ifndef ITEM_PATH
#define ITEM_PATH ROOT "/gamelib/clone/item/"
#endif
//购买物品模块
#define BUYD ((object)(ROOT "/gamelib/single/daemons/buyd.pike"))
//广播系统
#define BROADCASTD ((object)(ROOT "/gamelib/single/daemons/broadcastd"))
//VIP系统
#define VIPD ((object)(ROOT "/gamelib/single/daemons/vipd"))
//新职业会员助手（只提供自动化、报告与外观，不改变战斗数值）
#define PROFESSIONVIPD ((object)(ROOT "/gamelib/single/daemons/professionvipd.pike"))
//幻境区周期人物系统（宏名为历史兼容保留）
#define SEASONALD ((object)(ROOT "/gamelib/single/daemons/seasonal_chard.pike"))
//自动挂机系统
#define AUTOFIGHTD ((object)(ROOT "/gamelib/single/daemons/autofightd.pike"))
//个人挑战难度：同图同Worker，只调整本人PVE风险、套装掉落与挂机额度
#define PERSONAL_DIFFICULTYD ((object)(ROOT "/gamelib/single/daemons/personal_difficultyd.pike"))
//新月六阶十件套技能：只从当前真实穿戴重建，不另建玩家或Worker存储
#define NEWMOON_SET_SKILLD ((object)(ROOT "/gamelib/single/daemons/newmoon_set_skilld.pike"))
//召唤系统
#define SUMMOND ((object)(ROOT "/gamelib/single/daemons/summond.pike"))
//召唤物公共基类
#define GAMELIB_SUMMON_BASE ROOT "/gamelib/clone/npc/summon/base_summon"
//游戏公告
#define MSGD ((object)(ROOT "/gamelib/single/daemons/messaged"))
//抽奖模块
#define LOTTERYD ((object)(ROOT "/gamelib/single/daemons/lotteryd"))
//游戏间货币兑换
#define FEE_EXCHANGED ((object)(ROOT "/gamelib/single/daemons/fee_exchanged"))
//家园基本操作
#define HOMED ((object)(ROOT "/gamelib/single/daemons/homed"))
//挂机基本操作
#define AUTO_LEARND ((object)(ROOT "/gamelib/single/daemons/autolearnd"))
//问卷调查
#define DIAOCHAD ((object)(ROOT "/gamelib/single/daemons/diaochad"))
//附加技能上限
#define VICESKILL_UP 300
//普通玩家120级封顶；有效VIP每级增加20级。旧VIP1-4权益保持不变，
//新增VIP5-8后最高280级；系统安全上限仍保留到1000级。
#define NORMAL_MAX_LEVEL 120
#define VIP_LEVEL_LIMIT_STEP 20
#define VIP_MAX_LEVEL 8
#define MAX_LEVEL 1000
#define ENDGAME_MAP_MIN_LEVEL 990
//洞穴刷新出口操作
#define ROOM_FLUSHD ((object)(ROOT "/gamelib/single/daemons/room_flushd"))
//兑换物品守护模块
#define ITEMS_EXCHANGED ((object)(ROOT "/gamelib/single/daemons/items_exchanged"))
//地图显示
#define MAPD ((object)(ROOT "/gamelib/single/daemons/mapd"))
//空闲踢人守护模块
#define IDLE_KICKD ((object)(ROOT "/gamelib/single/daemons/idle_kickd"))
//HTTP API 守护模块
#define HTTP_APID ((object)(ROOT "/gamelib/single/daemons/http_api_daemon"))
//玩家意见反馈、后台审核与采纳奖励模块
#define FEEDBACKD ((object)(ROOT "/gamelib/single/daemons/feedbackd"))
//注册账号与独立人物档案的兼容索引
#define ACCOUNT_CHARACTERD ((object)(ROOT "/gamelib/single/daemons/account_characterd.pike"))
//注册账号独立共享宝库（个人仓库保持不变）
#define ACCOUNT_STORAGED ((object)(ROOT "/gamelib/single/daemons/account_storaged.pike"))
//账号共享宠物：山海万灵图鉴、培养、裂隙与灵宠论道
#define PETD ((object)(ROOT "/gamelib/single/daemons/petd.pike"))
//角色独立的本命灵伴；数据只进入该角色.o档案
#define SPIRIT_COMPANIOND ((object)(ROOT "/gamelib/single/daemons/spirit_companiond.pike"))
#define ACCOUNT_WALLETD ((object)(ROOT "/gamelib/single/daemons/account_walletd.pike"))
//注册邀请码、半年捐赠返玉与永久审计凭据
#define REFERRALD ((object)(ROOT "/gamelib/single/daemons/referrald.pike"))
//付费商城批量叠加、背包容量证明与精确回滚
#define SHOP_BATCHD ((object)(ROOT "/gamelib/single/daemons/shop_batchd.pike"))
//证据白名单限定的一次性历史异常玉石回收
#define JADE_RECOVERYD ((object)(ROOT "/gamelib/single/daemons/jade_recoveryd.pike"))
//同一物理进程内的逻辑分区、热开区与在线合区守护模块
#define LOGICALZONED ((object)(ROOT "/gamelib/single/daemons/logical_zoned.pike"))

#define MAP_WORKERD ((object)(ROOT "/gamelib/single/daemons/map_workerd.pike"))
#define MAP_WORKER_REDIRECT_ERROR "[MAP_WORKER_REDIRECT]"
//同房间、同 Worker 的玩家赠送与面对面交易事务
#define PLAYER_TRANSFERD ((object)(ROOT "/gamelib/single/daemons/player_transferd.pike"))
//每日限时原创玩法：天衡绝境（PVP）与九曜镇渊（PVE）
#define TIMED_EVENTD ((object)(ROOT "/gamelib/single/daemons/timed_eventd.pike"))

#endif // _GAMELIB_H_

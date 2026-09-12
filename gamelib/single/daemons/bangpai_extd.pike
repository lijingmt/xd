/**
 * 帮派扩展守护进程（建议7：跨阵营帮派玩法）。
 *
 * 分层模块：
 *   _bangpai_mod/core.pike     帮派建设、帮贡账本与共享状态持久化
 *   _bangpai_mod/boss.pike     每日帮派BOSS（伤害排行结算）
 *   _bangpai_mod/illusion.pike 每周六帮派幻境（限时副本）
 *   _bangpai_mod/shop.pike     帮贡商店
 *
 * 状态文件 data_xiand/bangpai/ext_state.json 为唯一权威：任何 Worker
 * 修改都在 mkdir 互斥锁内“重读→合并→原子写回”，读路径用
 * mtime+size 缓存失效，避免打怪热路径反复读盘。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define BANGPAI_EXT_STATE_VERSION 1
#define BANGPAI_EXT_STATE_FILE DATA_ROOT "bangpai/ext_state.json"
#define BANGPAI_EXT_LOCK_DIR DATA_ROOT "bangpai/.ext_lock"
#define BANGPAI_EXT_LOCK_STALE_SECONDS 15
#define BANGPAI_EXT_MAX_GANGS 512
#define BANGPAI_EXT_MAX_MEMBERS 4096
#define BANGPAI_EXT_DONATE_MIN 1000
#define BANGPAI_EXT_DONATE_MAX 10000000
#define BANGPAI_EXT_DONATE_CONTRIB_PER 1000
#define BANGPAI_EXT_DONATE_CONTRIB_DAILY 500
#define BANGPAI_EXT_MAX_LEVEL 10

// 各级所需累计建设度（银两）。等级只增不减。
private array(int) bangpai_level_costs = ({
	0,50000,200000,500000,1200000,2500000,5000000,9000000,
	15000000,25000000,
});

private mapping(string:mixed) bangpai_ext_state = ([]);
private int bangpai_ext_cache_mtime;
private int bangpai_ext_cache_size;
private int bangpai_ext_state_file_override;

#include "_bangpai_mod/core.pike"

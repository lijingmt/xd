/**
 * 山海万灵系统。
 *
 * 通用灵宠是账号级数据，不克隆NPC、不进入SUMMOND，也不占用方士三灵
 * 的数量、仇恨或共鸣。旧家园火云犬仍完全由HOMED管理。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))

#define PET_RECORD_VERSION 4
#define PET_LEVEL_MAX 60
#define PET_STAR_MAX 10
#define PET_BOND_MAX 5
#define PET_FILE_MAX_SIZE (4*1024*1024)
#define PET_STARTER_LEVEL 15
#define PET_EXCHANGE_MARKS 30
#define PET_FRAGMENT_HATCH_COST 60
#define PET_COSMETIC_DUST_COST 40
#define PET_DUEL_DAILY_OPPONENTS 3
#define PET_RIFT_MIN_MEMBERS 3
#define PET_RIFT_MAX_MEMBERS 5
#define PET_RIFT_MAX_ROUNDS 12
#define PET_RIFT_EXPIRE_SECONDS 1800
#define PET_INVITE_EXPIRE_SECONDS 120
#define PET_ASSIST_COOLDOWN 30
#define PET_PVP_ASSIST_USES 2
#define PET_PENDING_REWARD_SECONDS (7*86400)
#define PET_CACHE_MAX 2048
#define PET_PVE_FRAGMENT_DAILY_CAP 12
#define PET_GEAR_INVENTORY_MAX 60
#define PET_HIDDEN_LUAN_SPECIES "luanniao"
#define PET_HIDDEN_LUAN_PITY 500
#define PET_HIDDEN_LUAN_WORLD_CHANCE 2
#define PET_HIDDEN_LUAN_DUNGEON_CHANCE 5
#define PET_OWNER_REVIVE_LIFE_PERCENT 15
#define PET_OWNER_REVIVE_MOFA_PERCENT 10

private Thread.Mutex pet_lock = Thread.Mutex();
private mapping(string:mapping(string:mixed)) pet_cache = ([]);

// 裂隙、招募和论道邀请只属于当前进程；永久奖励凭据另存账号文件。
private mapping(string:mapping(string:mixed)) rift_sessions = ([]);
private mapping(string:mapping(string:mixed)) rift_recruits = ([]);
private mapping(string:mapping(string:mixed)) duel_invites = ([]);

#include "_pet_mod/catalog.pike"
#include "_pet_mod/growth.pike"
#include "_pet_mod/persistence.pike"
#include "_pet_mod/equipment.pike"
#include "_pet_mod/collection.pike"
#include "_pet_mod/rift.pike"
#include "_pet_mod/duel.pike"
#include "_pet_mod/assist.pike"

protected void create()
{
}

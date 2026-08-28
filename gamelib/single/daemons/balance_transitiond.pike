#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

// 平衡过渡期全局怪物强度：回收历史爆炸装后，玩家整体输出回落，
// 用可在线热调的全局系数在过渡期软化怪物，随合法装备成型逐步回
// 调到100。系数持久化在 data_xiand/balance_transition.json；无配置
// 或数值非法时一律保持100（测试与未启用过渡的区服不受影响），生产
// 由管理员显式下达 mgr_balance_transition 50 70 回收过渡。

#define BALANCE_FILE ROOT "/data_xiand/balance_transition.json"
#define BALANCE_CACHE_TTL 30

private int cached_life_percent=100;
private int cached_attack_percent=100;
private int cache_loaded_at;
private int cache_file_mtime;

private void refresh_cache()
{
	int now=time();
	// 热路径（每次NPC对玩家伤害都会查询）：TTL内直接用缓存，避免
	// 每次命中一次 file_stat 系统调用；过期后才查盘并校验mtime。
	if(cache_loaded_at && now-cache_loaded_at<BALANCE_CACHE_TTL)
		return;
	Stdio.Stat stat=file_stat(BALANCE_FILE);
	int mtime=stat ? (int)stat->mtime : 0;
	cache_loaded_at=now;
	cache_file_mtime=mtime;
	cached_life_percent=0;
	cached_attack_percent=0;
	if(mtime){
		mixed err=catch{
			mapping record=Standards.JSON.decode(
				Stdio.read_file(BALANCE_FILE));
			if(mappingp(record)){
				cached_life_percent=(int)record["life_percent"];
				cached_attack_percent=(int)record["attack_percent"];
			}
		};
		if(err){
			cached_life_percent=0;
			cached_attack_percent=0;
		}
	}
	if(cached_life_percent<10 || cached_life_percent>200)
		cached_life_percent=0;
	if(cached_attack_percent<10 || cached_attack_percent>200)
		cached_attack_percent=0;
	// 无持久配置时默认100%（回收过渡期已结束：生产205长期没有此
	// 文件，5%默认值让全服怪物维持纸糊血量，"首领被秒/毫无难度"
	// 的真正根源）。过渡期需要软化时由管理员显式下达
	// mgr_balance_transition 下发文件。
	if(!cached_life_percent)
		cached_life_percent=100;
	if(!cached_attack_percent)
		cached_attack_percent=100;
}

int query_life_percent()
{
	refresh_cache();
	return cached_life_percent;
}

int query_attack_percent()
{
	refresh_cache();
	return cached_attack_percent;
}

mapping(string:mixed) query_status()
{
	refresh_cache();
	return (["life_percent":cached_life_percent,
		"attack_percent":cached_attack_percent,
		"persisted":cache_file_mtime ? 1 : 0,
		"updated_at":cache_file_mtime]);
}

mapping(string:mixed) set_percents(int life_percent,int attack_percent,
	string reason)
{
	string payload;
	if(life_percent<10 || life_percent>200 ||
	   attack_percent<10 || attack_percent>200)
		return (["ok":0,"message":"系数必须在10到200之间。"]);
	payload=Standards.JSON.encode(([
		"version":1,
		"life_percent":life_percent,
		"attack_percent":attack_percent,
		"reason":reason || "",
		"updated_at":time(),
	]));
	Stdio.mkdirhier(dirname(BALANCE_FILE));
	if(!Stdio.write_file(BALANCE_FILE+".tmp",payload) ||
	   !mv(BALANCE_FILE+".tmp",BALANCE_FILE))
		return (["ok":0,"message":"系数持久化失败。"]);
	cache_loaded_at=0;
	Stdio.Stat stat=file_stat(BALANCE_FILE);
	cache_file_mtime=stat ? (int)stat->mtime : 0;
	mixed log_err=catch{
		Stdio.append_file(ROOT+"/log/balance_transition.log",
			ctime(time())[0..sizeof(ctime(time()))-2]+
			" life="+life_percent+" attack="+attack_percent+
			" reason="+(reason || "")+"\n");
	};
	return (["ok":1,"message":"怪物强度已调整：生命"+life_percent+
		"%、攻击"+attack_percent+"%（30秒内全服生效）。",
		"life_percent":life_percent,"attack_percent":attack_percent]);
}

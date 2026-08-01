/**
 * 同一物理进程内的逻辑分区门面。
 *
 * 业务代码只调用本 daemon 的 can_interact/can_user_interact 等稳定接口；
 * 配置格式、账号归属、隔离策略和在线关系清理由独立模块负责。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#include "_logical_zone_mod/config.pike"

// Read-copy-update：候选配置完全构建后才替换引用，读路径只访问不可变快照。
private mapping(string:mapping(string:mixed)) logical_zones = ([]);
private Thread.Mutex logical_zone_lock = Thread.Mutex();
private Thread.Mutex logical_zone_reload_lock = Thread.Mutex();
private Thread.Mutex logical_zone_admin_lock = Thread.Mutex();
private string logical_zone_signature = "";
private int logical_zone_generation = 0;
private int logical_zone_last_reload = 0;
private string logical_zone_last_error = "";

#include "_logical_zone_mod/identity.pike"
#include "_logical_zone_mod/config_loader.pike"
#include "_logical_zone_mod/policy.pike"
#include "_logical_zone_mod/capabilities.pike"
#include "_logical_zone_mod/management.pike"
#include "_logical_zone_mod/reconciliation.pike"

/** 返回热加载状态，供 API、运维命令和测试观察。 */
mapping(string:mixed) query_status()
{
	object key = logical_zone_lock->lock();
	mapping(string:mixed) result = ([
		"generation":logical_zone_generation,
		"last_reload":logical_zone_last_reload,
		"last_error":logical_zone_last_error,
		"zone_count":sizeof(logical_zones),
		"reload_interval":LOGICAL_ZONE_RELOAD_INTERVAL,
	]);
	destruct(key);
	return result;
}

/** 公开接口只提供健康摘要，不暴露配置文件名、错误详情或合区拓扑。 */
mapping(string:mixed) query_public_status()
{
	object key = logical_zone_lock->lock();
	mapping(string:mixed) result = ([
		"generation":logical_zone_generation,
		"last_reload":logical_zone_last_reload,
		"healthy":logical_zone_last_error=="",
		"zone_count":sizeof(logical_zones),
	]);
	destruct(key);
	return result;
}

/**
 * 构建并原子替换整份配置快照。
 * 任意文件非法时保留上一代快照，使开区、合区和回滚都不会出现半状态。
 */
int reload_zone_configs(void|int force)
{
	object reload_key = logical_zone_reload_lock->lock();
	mapping(string:mixed) built = build_zone_snapshot();
	mapping(string:mapping(string:mixed)) snapshot;
	string signature;
	object key;
	if(!(int)built["ok"]){
		int should_log_error = 0;
		key = logical_zone_lock->lock();
		if(logical_zone_last_error!=(string)built["error"])
			should_log_error = 1;
		logical_zone_last_error = (string)built["error"];
		destruct(key);
		if(should_log_error)
			werror("[LOGICALZONED] 配置热加载被拒绝: %s\n",
				logical_zone_last_error);
		destruct(reload_key);
		return 0;
	}
	snapshot = built["snapshot"];
	signature = (string)built["signature"];
	if(!force && signature==logical_zone_signature){
		key = logical_zone_lock->lock();
		logical_zone_last_error = "";
		destruct(key);
		destruct(reload_key);
		return 1;
	}
	key = logical_zone_lock->lock();
	logical_zones = snapshot;
	logical_zone_signature = signature;
	logical_zone_generation++;
	logical_zone_last_reload = time();
	logical_zone_last_error = "";
	destruct(key);
	destruct(reload_key);
	werror("[LOGICALZONED] 已热加载 %d 个逻辑区，generation=%d\n",
		sizeof(snapshot),logical_zone_generation);
	call_out(enforce_online_isolation,0);
	return 1;
}

private void check_zone_configs()
{
	reload_zone_configs(0);
	call_out(check_zone_configs,LOGICAL_ZONE_RELOAD_INTERVAL);
}

protected void create()
{
	mkdir(LOGICAL_ZONE_DIR);
	reload_zone_configs(1);
	call_out(check_zone_configs,LOGICAL_ZONE_RELOAD_INTERVAL);
}

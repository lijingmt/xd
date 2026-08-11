/**
 * 每日限时原创玩法守护进程。
 *
 * 天衡绝境：随机镜域1v1生存赛，杜绝多人围攻。
 * 九曜镇渊：九宫封脉与巡游首领协作战，不复用线性副本。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define EVENT_TIANHENG "tianheng"
#define EVENT_JIUYAO "jiuyao"
#define TIMED_EVENT_STATE_VERSION 1
#define TIMED_EVENT_TICK_SECONDS 2
#define TIMED_EVENT_CONFIG_FILE ROOT "/gamelib/etc/timed_events.json"
#define TIMED_EVENT_STATE_DIR DATA_ROOT "timed_events"
#define TIMED_EVENT_STATE_FILE TIMED_EVENT_STATE_DIR "/state.json"
#define TIMED_EVENT_CLAIM_ACK_DIR TIMED_EVENT_STATE_DIR "/claim_acks"
#define TIMED_EVENT_CLAIM_ACK_VERSION 1
#define TIMED_EVENT_CLAIM_ACK_MAX_BYTES 2048
#define TIMED_EVENT_CLAIM_ACK_BATCH 100
#define PLAYER_EVENT_ROOT "/plus/timed_event"

private mapping(string:mixed) timed_event_config = ([]);
private mapping(string:mapping(string:mixed)) sessions = ([]);
private mapping(string:mapping(string:object)) runtime_rooms = ([]);
private mapping(string:array(object)) runtime_npcs = ([]);
private mapping(string:int) announced_signup = ([]);
private int event_scheduler_started;
private int event_owner_probe_scheduled;
private int last_readonly_refresh;

private string timed_event_ingress_path()
{
	return "/gamelib/d/timed_event/tianheng_ingress.pike";
}

private int local_timed_event_owner()
{
	if(MAP_WORKERD->query_node_role()!="worker")
		return 1;
	return MAP_WORKERD->local_worker_owns_room(timed_event_ingress_path());
}

private void schedule_event_owner_probe(int delay)
{
	if(event_owner_probe_scheduled)
		return;
	event_owner_probe_scheduled = 1;
	call_out(probe_event_owner,delay);
}

private void probe_event_owner()
{
	event_owner_probe_scheduled = 0;
	if(MAP_WORKERD->query_node_role()!="worker")
		return;
	if(!MAP_WORKERD->local_affinity_assignments_ready()){
		schedule_event_owner_probe(2);
		return;
	}
	if(!local_timed_event_owner()){
		schedule_event_owner_probe(30);
		return;
	}
	if(event_scheduler_started)
		return;
	// Only the consistency-domain owner may interpret a persisted battle as an
	// interrupted runtime and advance/cancel it. Read-only worker copies must
	// never cancel the live owner's activity merely because they lazy-loaded.
	load_event_state(1);
	consume_reward_claim_acks();
	event_scheduler_started = 1;
	call_out(tick_sessions,2);
}

private void refresh_readonly_event_snapshot()
{
	if(MAP_WORKERD->query_node_role()!="worker" || local_timed_event_owner() ||
	   last_readonly_refresh+2>time())
		return;
	last_readonly_refresh = time();
	load_event_state(0);
}

#include "_timed_event_mod/config.pike"
#include "_timed_event_mod/persistence.pike"
#include "_timed_event_mod/runtime.pike"
#include "_timed_event_mod/shop.pike"
#include "_timed_event_mod/pvp.pike"
#include "_timed_event_mod/pve.pike"
#include "_timed_event_mod/view.pike"
#include "_timed_event_mod/core.pike"

protected void create()
{
	reload_config();
	if(MAP_WORKERD->query_node_role()=="worker"){
		load_event_state(0);
		schedule_event_owner_probe(2);
	}
	else{
		load_event_state(1);
		consume_reward_claim_acks();
		event_scheduler_started = 1;
		call_out(tick_sessions,2);
	}
}

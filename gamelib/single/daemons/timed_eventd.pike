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
#define PLAYER_EVENT_ROOT "/plus/timed_event"

private mapping(string:mixed) timed_event_config = ([]);
private mapping(string:mapping(string:mixed)) sessions = ([]);
private mapping(string:mapping(string:object)) runtime_rooms = ([]);
private mapping(string:array(object)) runtime_npcs = ([]);
private mapping(string:int) announced_signup = ([]);

#include "_timed_event_mod/config.pike"
#include "_timed_event_mod/persistence.pike"
#include "_timed_event_mod/runtime.pike"
#include "_timed_event_mod/pvp.pike"
#include "_timed_event_mod/pve.pike"
#include "_timed_event_mod/view.pike"
#include "_timed_event_mod/core.pike"

protected void create()
{
	reload_config();
	load_event_state();
	call_out(tick_sessions,2);
}

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit GAMELIB_NPC;

private string timed_event_id = "";
private string timed_event_session = "";
private string timed_event_role = "";

protected void create()
{
	name = object_name(this_object());
	name_cn = "渊息残影";
	desc = "一缕尚未凝成形体的渊息。\n";
	set_raceId("monst");
	set_profeId("humanlike");
	_npcLevel = 30;
	setup_npc();
}

void configure_timed_event_npc(string session_key,string role,
	string display_name,int level,int boss_flag,int desired_life,
	int desired_power)
{
	timed_event_id = "jiuyao";
	timed_event_session = session_key;
	timed_event_role = role;
	name_cn = display_name;
	desc = display_name+"循着未封闭的曜脉降临此地。\n";
	_npcLevel = level;
	_boss = boss_flag;
	setup_npc();
	if(desired_power>0){
		set_base_str(query_base_str()+desired_power);
		set_base_think(query_base_think()+desired_power);
	}
	if(desired_life<query_life_max())
		desired_life = query_life_max();
	set_base_life(query_base_life()+desired_life-query_life_max());
	flush_life();
	set_mofa(query_mofa_max());
}

int is_timed_event_npc(){ return 1; }
string query_timed_event_id(){ return timed_event_id; }
string query_timed_event_session(){ return timed_event_session; }
string query_timed_event_role(){ return timed_event_role; }

string query_links(void|int count)
{
	object me = this_player();
	if(me && TIMED_EVENTD->can_engage_event_npc(me,this_object()))
		return "[迎战:timed_event engage "+query_name()+"]\n";
	return "";
}

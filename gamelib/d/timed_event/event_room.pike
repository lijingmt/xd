#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit WAP_ROOM;

private string timed_event_id = "";
private string timed_event_session = "";
private string timed_event_node = "";
private string timed_event_kind = "";

protected void create()
{
	name = object_name(this_object());
	name_cn = "限时秘境";
	desc = "这里是由天衡司暂时开启的独立秘境。\n";
	set_room_type("timed_event");
	exits = ([]);
}

void configure_timed_event_room(string event_id,string session_key,
	string node,string kind,string room_name,string room_desc)
{
	timed_event_id = event_id;
	timed_event_session = session_key;
	timed_event_node = node;
	timed_event_kind = kind;
	name_cn = room_name;
	desc = room_desc;
}

int is_peaceful(){ return 1; }
int is_timed_event_room(){ return 1; }
string query_timed_event_id(){ return timed_event_id; }
string query_timed_event_session(){ return timed_event_session; }
string query_timed_event_node(){ return timed_event_node; }
string query_timed_event_kind(){ return timed_event_kind; }

string query_desc()
{
	return desc+TIMED_EVENTD->query_room_event_desc(
		this_player(),timed_event_session,timed_event_node);
}

string query_links(void|int count)
{
	return TIMED_EVENTD->query_room_event_links(
		this_player(),timed_event_session,timed_event_node);
}

string view_exits(){ return ""; }

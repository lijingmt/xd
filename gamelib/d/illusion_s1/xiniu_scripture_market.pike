#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=30;
protected void create(){
	name=object_name(this_object());
	name_cn="西牛万法集";
	desc="功法、师承和来世都被摆上高台竞价。最穷的弟子跪在最下面，却未必比买走秘典的人离大道更远。\n";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/mirror_lake.pike";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/xiniu_empty_temple.pike";
}
string query_links(){ return "[查看万法价目:illusion_realm witness]\n"; }

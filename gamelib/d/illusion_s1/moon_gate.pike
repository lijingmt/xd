#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=1;
protected void create(){
	name=object_name(this_object());
	name_cn="S1月门营地";
	desc="新月悬在天幕正中，三条尚未被书写的命途从月门下延伸。这里是新月幻境·S1唯一安全营地。\n";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/silver_path.pike";
	exits["north"]=ROOT "/gamelib/d/illusion_s1/nanzhan_mortal_city.pike";
}
int is_peaceful(){ return 1; }
int is_bedroom(){ return 1; }
string query_links(){
	return "[查看S1历程:illusion_realm]\n"+
		"[设置复活点:set_relife /gamelib/d/illusion_s1/moon_gate.pike]\n"+
		"[休息:sleep]\n";
}

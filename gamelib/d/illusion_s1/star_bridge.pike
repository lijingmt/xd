#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=50;
protected void create(){
	name=object_name(this_object());
	name_cn="断星桥";
	desc="守桥者只承认亲手走到这里的人。多人同行会推进同心路线，但奖励仍逐人结算。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/echo_ruins.pike";
	exits["south"]=ROOT "/gamelib/d/illusion_s1/abyss_garden.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/star_keeper.pike"}));
}

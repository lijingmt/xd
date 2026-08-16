#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=36;
protected void create(){
	name=object_name(this_object());
	name_cn="镜湖沉月渊";
	desc="湖底每一块碎镜都保存着一个本可发生的结局。镜主以遗憾为丝，专门把最舍不得醒的人留在这里。\n";
	exits["east"]=ROOT "/gamelib/d/illusion_s1/mirror_lake.pike";
	add_items(({ROOT "/gamelib/clone/npc/illusion_s1/mirror_weaver.pike"}));
}

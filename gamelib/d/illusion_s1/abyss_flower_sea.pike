#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
string room_race="third";
protected int room_level=50;
protected void create(){
	name=object_name(this_object());
	name_cn="渊花海";
	desc="大片月花沿深渊开放，这是所有幻境行者共享的中立深渊猎场。\n";
	exits["west"]=ROOT "/gamelib/d/illusion_s1/abyss_garden.pike";
	// 50档是最后一档静态猎场；51级起开启动态同级怪，填补55-69的
	// 等级与经验断层，文件名不变以保住章节击杀判定。
	dongtai_npc_start_level=51;
	configure_autofight_training_population(ROOT "/gamelib/clone/npc/illusion_s1/abyss_beast.pike",32,28,5,24,3);
}

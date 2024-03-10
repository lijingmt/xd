#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令列出玩家身上可供属性转换的装备列表
int main(string arg)
{
	string s = "选择你需要炼化的装备\n";
	object me=this_player();
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob){
		if(ob && ITEMSD->can_equip(ob) &&((ob->query_item_rareLevel()>0)||(ob->query_item_canLevel()>=1&&(sizeof(ob->query_name_cn()/"】"))==1))){
			s += "["+ob->query_name_cn()+":convert_equip_detail "+ob->query_name()+" 0]\n";
		}
	}
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}

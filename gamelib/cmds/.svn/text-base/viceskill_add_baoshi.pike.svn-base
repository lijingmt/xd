#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = p_id 
//此指令列出玩家可以加入的宝石
int main(string arg)
{
	string s = "请选择你要加入的宝石，每种宝石只能加入一颗。\n";
	object me=this_player();
	array(object) all_obj = all_inventory(me);
	int p_id = (int)arg;
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && ob->query_for_material() == "baoshi"){
			if(me->baoshi_add[ob->query_name()] == 0){
				s += "["+ob->query_name_cn()+":viceskill_pf_detail duanzao "+p_id+" 1 "+ob->query_name()+"]";
				s += "("+me->material_m[ob->query_name()]+")\n";
			}
		}
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:viceskill_pf_detail duanzao "+p_id+" 1 none]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}

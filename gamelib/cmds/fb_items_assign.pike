#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = team_id index item_file 
//team_id 队伍号
//index   此物品在队伍仓库数组的下标号，作为删除已分配物品时用
//item_file 物品文件名，后面有个指针号，所以要进行#分割
//fg 物品的指针地址，用来判断是否是已分配的物品
int main(string arg)
{
	string s = "";
	object me=this_player();
	string termid = "";
	string item_file = "";
	int index = 0;
	int fg = 0;
	sscanf(arg,"%s %d %s %d",termid,index,item_file,fg);
	string team_id = me->query_term();
	if(team_id == "noterm" || team_id != termid){
		s += "你已经没有在这个队伍里了\n";
		s += "[返回:look]\n";
		write(s);
		return 1;
	}
	if(TERMD->if_have_assigned(termid,item_file,fg,index) == 1){
		s += "仓库里已经没有此物品。\n";
		s += "[返回:fb_term_cangku "+termid+" 1]\n";
		write(s);
		return 1;
	}
	else{
		string new_item_file = (item_file/"#")[0];
		object item = clone(new_item_file);
		if(item){
			s += "你将"+item->query_name_cn()+"分配给：\n";
			//在这儿加入对帮战特殊幻境出的装的过滤,由liaocheng于08/09/3添加 
			if(item->query_item_from() == "bangzhan")
				s += TERMD->query_termers_for_assign_bz(termid,item_file,fg,index);
			else
				s += TERMD->query_termers_for_assign(termid,item_file,fg,index);
		}
	}
	s += "\n[返回:my_term]\n";
	write(s);
	return 1;
}

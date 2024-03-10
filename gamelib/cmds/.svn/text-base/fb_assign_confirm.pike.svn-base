#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = termer team_id item_file index
//termer 要分配给的队友id
//team_id 队伍号
//item_file 物品文件名
//index   此物品在队伍仓库数组的下标号，作为删除已分配物品时用
int main(string arg)
{
	string s = "";
	object me=this_player();
	string to_id= "";
	string termid = "";
	string item_file = "";
	int fg = 0;
	int index = 0;
	sscanf(arg,"%s %s %s %d %d",to_id,termid,item_file,fg,index);
	string team_id = me->query_term();
	if(team_id == "noterm" || team_id != termid){
		s += "你已经没有在这个队伍里了\n";
		s += "[返回:look]\n";
		write(s);
		return 1;
	}
	else{
		if(TERMD->if_have_assigned(termid,item_file,fg,index) == 1){
			s += "仓库里已经没有此物品。\n";
			s += "[返回:fb_term_cangku "+termid+" 1]\n";
			write(s);
			return 1;
		}
		object to = find_player(to_id);
		werror("-----"+to->query_name_cn()+"-----\n");
		if(!to || to->query_term() != termid){
			s += "分配失败！对方不在线或者已经退出了队伍\n";
			s += "[返回:fb_term_cangku "+termid+" 1]\n";
			write(s);
			return 1;
		}
		object item = clone(item_file);
		if(item){
			if(to->if_over_load(item)){
				s += "分配失败！对方包裹已满\n";
				s += "[返回:fb_term_cangku "+termid+" 1]\n";
				write(s);
				return 1;
			}
			else{
				string now=ctime(time());
				string log_s = me->query_name_cn()+"("+me->query_name()+")将 "+item->query_name_cn()+" 分配给了 "+to->query_name_cn()+"("+to->query_name()+")";
				Stdio.append_file(ROOT+"/log/get_bossItem.log",now[0..sizeof(now)-2]+":"+log_s+"\n");
				s += "队长将 "+item->query_name_cn()+" 分配给了 "+to->query_name_cn()+"。\n";
				if(item->is("combine_item"))
					item->move_player(to->query_name());
				else
					item->move(to);
				TERMD->delete_termItems(termid,index);
				TERMD->term_tell(termid,s);
				me->command("fb_term_cangku "+termid+" 1");
			}
		}
		else {
			s += "无法得到此物品！\n";
			s += "[返回:fb_term_cangku "+termid+" 1]\n";
			write(s);
			return 1;
		}
	}
	return 1;
}

#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = room_name room_num flag
//flag = 0 表示此时玩家在副本外
//     = 1 表示此时玩家在副本内
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	string room_name = "";
	int room_num = 0;
	int flag = 0;
	//desc+="[进入【幻境】冥府:fb_entry mingfu 0 0]\n";
	sscanf(arg,"%s %d %d",room_name,room_num,flag);
	string team_id = me->query_term();
	if(team_id == "noterm"){
		if(flag == 0){
			s += "只有队伍才能进入\n";
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
		if(flag == 1){
			//如果玩家在副本内离开队伍，那么他会被传送到复活点
			s += "由于你离开了队伍，你将被传送回入口处\n";
			s += "\n[确定:fb_leave "+room_name+"]\n";
			write(s);
			return 1;
		}
	}
	else{
		//对于帮战排名第一的专属幻境，在进入时要做判断
		//由liaocheng于07/09/03添加
		if(room_name == "bawangmoku"){
			if(me->bangid != BANGZHAND->query_top_bang(1)){
				s += "只有霸气排行第一的帮派成员能够入内\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
			else if(!BANGZHAND->query_open_fg()){
				s += "排行尚未开始，暂未开放此幻境\n";
				s += "[返回:look]\n";
				write(s);
				return 1;
			}
		}
		//desc+="[进入【幻境】冥府:fb_entry mingfu 0 0]\n";
		object room = FBD->query_fb_room(room_name,room_num,team_id,flag);
		if(room){
			string next_fb_id = flag==0 ? team_id+"/"+room_name :
				(string)(me->fb_id || "");
			if(next_fb_id==""){
				write("副本身份已经失效，请先返回入口后重新进入。\n[确定:fb_leave "+room_name+"]\n");
				return 1;
			}
			int moved;
			mixed move_err = catch { moved = me->move(room); };
			if(move_err || !moved || environment(me)!=room){
				write("该副本当前位于其他地图节点，请稍后重试。\n[返回:look]\n");
				return 1;
			}
			me->fb_id = next_fb_id;
			FBD->add_fb_members(next_fb_id,me->query_name());
			me->inhome_pos="";//由于家园和副本会把玩家的last_pos这个字段设置为类似的结构，所以，进入副本之后，就要清空玩家在家园中的标志，以此来区分 副本 和 家园；Evan 2008.9.22
			me->reset_view();
			me->command("look");
			return 1;
		}
		else{
			s += "由于队伍的重组或者幻境重置，你们被传送回入口处。\n";
			s += "\n[确定:fb_leave "+room_name+"]\n";
			write(s);
			return 1;
		}
	}
	return 1;
}

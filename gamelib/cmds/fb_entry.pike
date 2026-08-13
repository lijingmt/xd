#include <command.h>
#include <gamelib/include/gamelib.h>
#define FB_WORKER_INGRESS "/gamelib/d/fb_runtime/ingress.pike"
//arg = room_name room_num flag
//flag = 0 表示此时玩家在副本外
//     = 1 表示此时玩家在副本内

private int route_player_to_fb_ingress(object player,string fb_id)
{
	object room;
	int moved;
	mixed move_err;
	if(!player || fb_id=="" || sizeof(fb_id)>160 || search(fb_id,"..")!=-1)
		return 0;
	move_err=catch { room=(object)(ROOT+FB_WORKER_INGRESS); };
	if(move_err || !room)
		return 0;
	player->fb_id=fb_id;
	move_err=catch { moved=player->move(room); };
	return !move_err && moved;
}

int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	string room_name = "";
	int room_num = 0;
	int flag = 0;
	//desc+="[进入【幻境】冥府:fb_entry mingfu 0 0]\n";
	if(!arg || sscanf(arg,"%s %d %d",room_name,room_num,flag)!=3 ||
	   room_num<0 || (flag!=0 && flag!=1) ||
	   !sizeof(FBD->query_safe_fb_entrance(room_name))){
		write("幻境入口参数无效，请从地图入口重新进入。\n[返回:look]\n");
		return 1;
	}
	string team_id = me->query_term();
	if(team_id == "" || team_id == "noterm" ||
	   !TERMD->query_termId(team_id)){
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
		string next_fb_id = flag==0 ? team_id+"/"+room_name :
			(string)(me->fb_id || "");
		if(next_fb_id==""){
			write("副本身份已经失效，请先返回入口后重新进入。\n"+
				"[确定:fb_leave "+room_name+"]\n");
			return 1;
		}
		// 动态克隆房不能直接作为跨 Worker 到达点。先经可重建的静态
		// ingress 按 team/fb_name 汇聚，再由唯一 owner 创建副本实例。
		if(flag==0 && MAP_WORKERD->query_node_role()=="worker" &&
		   !MAP_WORKERD->local_worker_owns_room(
			FB_WORKER_INGRESS,next_fb_id)){
			if(route_player_to_fb_ingress(me,next_fb_id))
				return 1;
			me->fb_id=0;
			write("幻境节点切换失败，本次没有建立副本，请稍后重试。\n"+
				"[返回:look]\n");
			return 1;
		}
		//desc+="[进入【幻境】冥府:fb_entry mingfu 0 0]\n";
		object room = FBD->query_fb_room(room_name,room_num,team_id,flag);
		if(room){
			int moved;
			mixed move_err = catch { moved = me->move(room); };
			if(move_err || !moved || environment(me)!=room){
				write("幻境实例尚未在当前节点就绪，请返回中转通道继续。\n"+
					"[继续进入:fb_entry "+room_name+" "+room_num+
					" "+flag+"] [安全离开:fb_leave "+room_name+"]\n");
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

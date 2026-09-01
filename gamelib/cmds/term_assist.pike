#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		s += "你要邀请谁加入队伍？";
		s += "[邀请同房间所有人:term_invite_room]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else{
		object ob = find_player(arg);
		mapping remote = !ob && MAP_WORKERD->query_node_role()=="worker" ?
			MAP_WORKERD->query_local_online_user(arg) : ([]);
		int remote_compatible = (int)remote["ok"] &&
			LOGICALZONED->can_user_action("team",me->query_name(),arg) &&
			((string)me->query_raceId()==(string)remote["race_id"] ||
			 (string)me->query_raceId()=="third" ||
			 (string)remote["race_id"]=="third");
		if((ob && LOGICALZONED->can_interact(me,ob)) || remote_compatible){
			if(!ob){
				int invite_result = TERMD->create_term_invite(
					me->query_name(),arg);
				s += invite_result==1 ?
					"跨地图组队邀请已经发出，对方可从队伍页面处理。\n" :
					"组队邀请发送失败，对方可能已经加入其他队伍。\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			if(ob->query_term()!="" && ob->query_term()!="noterm" &&
			   !TERMD->query_termId(ob->query_term()))
				ob->set_term("noterm");
			if(ob->query_term()!=""&&ob->query_term()!="noterm"){
				s += "对方已经加入了某个队伍，请返回。\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			if(ob->query_name()==me->query_name())
				s += "你不能自己邀请自己，请返回。\n";
			else{
				int invite_result = TERMD->create_term_invite(
					me->query_name(),ob->query_name());
				if(invite_result==1){
					tell_object(ob,me->query_name_cn()+"邀请你加入一个队伍，是否同意？\n[同意:term_ok "+me->query_name()+"] [拒绝:term_refuse "+me->query_name()+"]\n");
					s += "组队邀请已经发出；网页玩家会自动弹出邀请，对方也可从队伍页面处理。\n";
				}
				else
					s += "组队邀请发送失败，对方可能已经加入其他队伍。\n";
			}
		}
		else{
			s += "你要邀请谁加入队伍？";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}

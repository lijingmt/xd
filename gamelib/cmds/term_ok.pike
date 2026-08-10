#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	//如果被邀请者已经有了队伍id，还要判断当前调用者本身是否已经有了队伍属性
	//才能将该用户加入该队列
	if(me->query_term()!=""&&me->query_term()!="noterm"){
		s += "你已经加入了某个队伍，请返回。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(!arg){
		s += "你要加入谁的队伍？";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(!TERMD->valid_term_invite(me->query_name(),arg)){
		s += "这条组队邀请不存在或已经过期，请让对方重新邀请。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	object ob = find_player(arg);
	if(!ob && MAP_WORKERD->query_node_role()=="worker"){
		mapping invite = TERMD->query_term_invite(me->query_name());
		mapping remote = MAP_WORKERD->query_local_online_user(arg);
		string remote_team_id = (string)(invite["team_id"] || "");
		// The coordinator publishes online and team snapshots independently.
		// Keep a still-valid invite when either snapshot is between generations;
		// the gateway team fence will drain it before the next retry.
		if(!(int)remote["ok"] || remote_team_id=="" ||
		   !TERMD->query_termId(remote_team_id)){
			s += "队伍状态正在跨地图同步，请稍后再次点击同意。\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		if(!LOGICALZONED->can_user_action("team",arg,me->query_name()) ||
		   !((string)me->query_raceId()==(string)remote["race_id"] ||
		     (string)me->query_raceId()=="third" ||
		     (string)remote["race_id"]=="third")){
			TERMD->clear_term_invite(me->query_name(),arg);
			s += "该组队邀请已不符合阵营或逻辑分区规则。\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		int remote_add = TERMD->add_termer(remote_team_id,
			me->query_name(),me->query_name_cn());
		if(remote_add==1){
			TERMD->clear_term_invite(me->query_name(),arg);
			s += "你加入了该队伍，队伍状态正在同步到其他地图。\n";
		}
		else if(remote_add==2)
			s += "队伍人数已经5人，无法加入该队伍。\n";
		else if(remote_add==4){
			TERMD->clear_term_invite(me->query_name(),arg);
			s += "该组队邀请已不符合逻辑分区规则。\n";
		}
		else
			s += "加入队伍失败，请让对方重新邀请。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(ob && LOGICALZONED->can_interact(me,ob)){
		if(ob->query_term()!="" && ob->query_term()!="noterm" &&
		   !TERMD->query_termId(ob->query_term()))
			ob->set_term("noterm");
		/*if(ob->query_term()!=""&&ob->query_term()!="noterm"){
			s += "对方已经加入了某个队伍，请返回。\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}*/
		//如果该邀请者队伍不存在，由邀请者创建队伍，并加入队伍
		if(ob->query_term()==""||ob->query_term()=="noterm"){
			string tid = (string)TERMD->term_create(ob->query_name());
			if(sizeof(tid)==1){
				//创建失败
				s += "加入队伍失败，请下次重试。\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			else{
				//创建成功，创立者加入，被邀请者也要加入队伍操作
				int add_result = TERMD->add_termer(
					tid,me->query_name(),me->query_name_cn());
				if(add_result==1){
					TERMD->clear_term_invite(me->query_name(),arg);
					s += "你加入了该队伍。\n";
				}
				else{
					TERMD->destory_term(tid,ob->query_name());
					s += "加入队伍失败，请让对方重新邀请。\n";
				}
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
		}
		else{
			int tmp = TERMD->add_termer(ob->query_term(),me->query_name(),me->query_name_cn());	
			switch(tmp){
				case 1:
					TERMD->clear_term_invite(me->query_name(),arg);
					s += "你加入了该队伍。\n";
					break;
				case 2:
					s += "队伍人数已经5人，无法加入该队伍。\n";	
					break;
				case 3:
				case 0:
					s += "加入队伍失败，请返回重试。\n";
					break;
			}
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	else{
		TERMD->clear_term_invite(me->query_name(),arg);
		s += "你要加入的队伍不存在。\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	return 1;
}

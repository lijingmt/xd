#include <command.h>
#include <gamelib/include/gamelib.h>
// 同房间一键组队：向当前房间所有可交互的玩家发出组队邀请。
// 逐个走 create_term_invite 同一套校验（逻辑分区、已有队伍、
// 跨Worker邀请），被邀请者仍需 term_ok 确认。
int main(string|zero arg)
{
	object me = this_player();
	object env;
	int invited = 0;
	int busy = 0;
	int blocked = 0;
	string s;
	if(!me || !(env=environment(me))){
		write("位置异常，无法发起邀请。\n[返回游戏:look]\n");
		return 1;
	}
	if(functionp(me->query_in_combat) && me->query_in_combat()){
		write("战斗中不能发起组队邀请。\n[返回游戏:look]\n");
		return 1;
	}
	foreach(all_inventory(env),object ob){
		if(!ob || ob==me || !ob->is("player"))
			continue;
		if(!functionp(ob->query_name) || !LOGICALZONED->can_interact(me,ob)){
			blocked++;
			continue;
		}
		if(ob->query_term()!="" && ob->query_term()!="noterm"){
			if(TERMD->query_termId(ob->query_term())){
				busy++;
				continue;
			}
			ob->set_term("noterm");
		}
		if(TERMD->create_term_invite(me->query_name(),
		   ob->query_name())==1){
			tell_object(ob,me->query_name_cn()+
				"邀请你加入一个队伍，是否同意？\n"+
				"[同意:term_ok "+me->query_name()+"] "+
				"[拒绝:term_refuse "+me->query_name()+"]\n");
			invited++;
		}
		else
			busy++;
	}
	s = "【同房邀请】已向"+invited+"人发出组队邀请";
	if(busy)
		s += "，"+busy+"人已在其他队伍或邀请失败";
	if(blocked)
		s += "，"+blocked+"人因分区/阵营限制跳过";
	s += "。\n[返回游戏:look]\n";
	write(s);
	return 1;
}

#include <command.h>
#include <gamelib/include/gamelib.h>

// 太极·复阴：主动复活同房同队的鬼魂队友。
// 5 分钟冷却（独立于自复活）；PVP 中也可施放。

int main(string|zero arg)
{
	object me = this_player();
	object target;
	string target_name;
	string s = "";
	string team_c;
	string team_t;
	int remaining;
	if(!me)
		return 0;
	if(me->query_profeId()!="taiji"){
		write("只有太极职业才能施展复阴。\n");
		return 1;
	}
	remaining = me->query_taiji_team_revive_remaining_cast(me);
	if(remaining > 0){
		int min = remaining/60;
		int sec = remaining%60;
		write("太极·复阴还需 "+min+" 分 "+sec+" 秒才能再次施展。\n");
		return 1;
	}
	if(!arg || String.trim_all_whites(arg)==""){
		// 列出同房同队的鬼魂队友
		object env = environment(me);
		array(string) candidates = ({});
		if(env){
			team_c = (string)me->query_term();
			if(team_c!="" && team_c!="noterm"){
				foreach(all_inventory(env),object ob){
					if(ob && ob->is("player") && ob->is("ghost") &&
				   (string)ob->query_term()==team_c && ob!=me)
						candidates += ({(string)ob->query_name()});
				}
			}
		}
		if(sizeof(candidates)==0){
			write("当前房间没有可复阴的同队鬼魂队友。\n");
			write("[返回游戏:look]\n");
			return 1;
		}
		s += "请选择要复阴的同队鬼魂队友：\n";
		foreach(candidates,string nm)
			s += "[复阴 "+nm+":taiji_fuyin "+nm+"]\n";
		write(s);
		return 1;
	}
	target_name = String.trim_all_whites(arg);
	target = find_player(target_name);
	if(!target || !objectp(target)){
		write("找不到叫 "+target_name+" 的人物。\n");
		return 1;
	}
	if(environment(me) != environment(target)){
		write(target->query_name_cn()+"不在你当前房间。\n");
		return 1;
	}
	if(!target->is("player")){
		write(target->query_name_cn()+"不是玩家角色。\n");
		return 1;
	}
	if(!target->is("ghost")){
		write(target->query_name_cn()+"还不是鬼魂，无需复阴。\n");
		return 1;
	}
	team_c = (string)me->query_term();
	team_t = (string)target->query_term();
	if(team_c=="" || team_c=="noterm" || team_c != team_t){
		write(target->query_name_cn()+"和你不在同一队伍。\n");
		return 1;
	}
	if(me->try_taiji_team_revive(me,target)){
		write("你施展太极·复阴，"+target->query_name_cn()+
			"自幽冥归来。\n");
		return 1;
	}
	write("复阴失败（未知原因），请联系管理员。\n");
	return 1;
}

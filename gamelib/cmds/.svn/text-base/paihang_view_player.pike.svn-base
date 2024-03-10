#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令查看在榜人员的个人信息
//arg = player_name raceId profeId level flag
int main(string arg)
{
	string s = "";
	string name_cn = "";
	string raceId = "";
	string profeId = "";
	int level = 0;
	int bangid = 0;
	int flag = 0;
	object me=this_player();
	sscanf(arg,"%s %s %s %d %d %d",name_cn,raceId,profeId,level,bangid,flag);
	s += name_cn+"：\n";
	if(bangid){
		string bang_name = BANGD->query_bang_name(bangid);
		if(bang_name && sizeof(bang_name)){
			s += "帮派：＜"+bang_name+"＞\n";
		}
	}

	string race_cn = "妖魔";
	if( raceId == "human")
		race_cn = "人类";
	s += "阵营："+race_cn+"\n";
	
	s += "等级："+level+"\n";
	string profe_cn = me->query_profe_cn(profeId);
	s += "职业："+profe_cn+"\n";
	if(flag == 0)
		s += "\n[返回排行榜:paihang_mark_toplist]\n";
	else
		s += "\n[返回排行榜:paihang_account_toplist]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}

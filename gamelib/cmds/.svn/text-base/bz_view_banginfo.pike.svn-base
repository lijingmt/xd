#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令查看参加帮战的帮派信息
//arg = bangid flag
//flag == 1标示有[申请入帮]的链接
int main(string arg)
{
	string s = "";
	object me=this_player();
	int bangid = 0;
	int flag = 0;
	sscanf(arg,"%d %d",bangid,flag);
	string race = "monst";
	string race_cn = "妖魔";
	if(bangid%2 == 0){
		race = "human";
		race_cn = "人类";	
	}
	s += "<"+BANGD->query_bang_name(bangid)+">：\n";
	s += "阵营："+race_cn+"\n";
	s += "帮主："+BANGD->query_root_name_cn(me,bangid)+"\n";
	s += "人数："+BANGD->query_nums(bangid,"online")+"/"+BANGD->query_nums(bangid,"all")+"\n";
	s += "帮派简介："+BANGD->query_bang_desc(bangid)+"\n";
	if(flag == 1)
		s += "[返回排行:bz_top_list]\n";
	else
		s += "[返回帮派列表:bz_view_list]\n";
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}

#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令查看帮战生死状的总信息
int main(string arg)
{
	string s = "";
	object me=this_player();
	s += "帮战生死状：\n";
	s += "凡申请加入生死状的所有帮派，其帮员在中立地区将可相互杀戮，并从中为帮派赢得霸气，以参加帮派排名。\n";
	s += "加入之后，您的帮员将处于更加险恶的环境之中。作为一帮之主的您，请慎重考虑！\n\n";
	if(BANGZHAND->if_in_bangzhan(me->bangid))
		s += "[退出生死状:bz_quit 0]\n";
	else
		s += "[加入生死状:bz_apply_in 0]\n";
	s += "[查看生死状:bz_view_list]\n";
	s += "[返回:look]\n";
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}

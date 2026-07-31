#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	mapping invite = TERMD->query_term_invite(me->query_name());
	NEWBIED->record_action(me,"team");
	s += "七星阵状：况\n";
	if(invite["pending"]){
		s += invite["from_name"]+"邀请你加入队伍。\n";
		s += "[同意:term_ok "+invite["from"]+"] ";
		s += "[拒绝:term_refuse "+invite["from"]+"]\n--------\n";
	}
	if(me->query_term()!="" && me->query_term()!="noterm" &&
	   !TERMD->query_termId(me->query_term()))
		me->set_term("noterm");
	s += TERMD->query_termStatus(me->query_term(),me->query_name());
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
